class_name StagingDirector
extends RefCounted

## 演出キューシステム（前方再生方式）。
## state_updated / actions_received をキューに積み、await ベースで直列処理する。
## イベントを1つずつ処理し、各イベント事後のスナップショットでUIを更新 → アニメーション。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const _TurnStartBannerScene: PackedScene = preload("res://scenes/gui/animation/turn_start_banner.tscn")
const _SkillCutInScene: PackedScene = preload("res://scenes/gui/animation/skill_cutin.tscn")
const FLY_DURATION: float = 0.35
const FLIP_DURATION: float = 0.3
const EVENT_DELAY: float = 0.15
const PIVOT: Vector2 = Vector2(150, 210)  # CardView の pivot_offset

enum _CueType { STATE_UPDATE, ACTIONS, BANNER }

# --- UI 参照 (GameScreen が設定) ---
var hand: HandZone
var opp_hand: HandZone
var card_layer: CardLayer
var deck_view: DeckView
var home_view: HomeView
var field_layout: FieldLayout

## UI を新しい ClientState で即更新するコールバック: func(cs: ClientState) -> void
var refresh_fn: Callable

## actions キュー処理時に呼ばれるコールバック: func(actions: Array) -> void
var on_actions_ready: Callable

# --- 内部状態 ---
var _anim_layer: Control
var _queue: Array = []          # [{type, cs_final?, event_entries?, actions?}]
var _processing: bool = false
var _prev_cs: ClientState       # 前回の ClientState（位置キャプチャ用）
var _cancelled: bool = false


func _init(anim_layer: Control) -> void:
	_anim_layer = anim_layer


# ===========================================================================
# 公開 API
# ===========================================================================

## state_updated 受信時に呼ぶ。
func enqueue_state_update(cs_final: ClientState, event_entries: Array) -> void:
	_queue.append({
		"type": _CueType.STATE_UPDATE,
		"cs_final": cs_final,
		"event_entries": event_entries,
	})
	_try_process()


## actions_received 受信時に呼ぶ。
func enqueue_actions(actions: Array) -> void:
	_queue.append({
		"type": _CueType.ACTIONS,
		"actions": actions,
	})
	_try_process()


## バナー演出をキューに積む。
func enqueue_banner(banner_scene: PackedScene) -> void:
	_queue.append({
		"type": _CueType.BANNER,
		"banner_scene": banner_scene,
	})
	_try_process()


## 初回描画用。prev_cs を設定し、refresh を即実行する。
func initialize(cs: ClientState) -> void:
	_prev_cs = cs
	if refresh_fn.is_valid():
		refresh_fn.call(cs)


## セッション切断時の全クリーンアップ。
func cancel_all() -> void:
	_cancelled = true
	_queue.clear()

	# AnimationLayer 上の一時カードを全削除
	for child in _anim_layer.get_children():
		child.queue_free()


# ===========================================================================
# キュー処理ループ
# ===========================================================================

func _try_process() -> void:
	if _processing:
		return
	_processing = true
	_cancelled = false
	await _process_queue()
	_processing = false


func _process_queue() -> void:
	while _queue.size() > 0:
		if _cancelled:
			break
		var entry: Dictionary = _queue.pop_front()
		var cue_type: int = entry.get("type", -1)
		match cue_type:
			_CueType.STATE_UPDATE:
				await _process_state_cue(entry)
			_CueType.ACTIONS:
				_process_actions_cue(entry)
			_CueType.BANNER:
				await _process_banner_cue(entry)


func _process_state_cue(entry: Dictionary) -> void:
	var cs_final: ClientState = entry.get("cs_final")
	var event_entries: Array = entry.get("event_entries", [])

	for ee in event_entries:
		if _cancelled:
			break
		var event: Dictionary = ee.get("event", {})
		var snapshot: ClientState = ee.get("snapshot")

		# 1) 旧状態の位置スナップショット
		var old_positions: Dictionary = _capture_positions(_prev_cs)

		# 2) 1イベント分だけUI更新
		if refresh_fn.is_valid() and snapshot != null:
			refresh_fn.call(snapshot)

		# 3) 変化したカードを非表示（ゾーン移動 or face_down変化）
		var hidden: Array = _hide_changed_cards(_prev_cs, snapshot)

		# 4) トークン消滅検知＋アニメ
		if _prev_cs != null and snapshot != null:
			var consumed: Array = field_layout.get_consumed_token_keys(
				_prev_cs.field_effects, snapshot.field_effects)
			for key in consumed:
				if _cancelled:
					break
				await field_layout.play_consume_animation(key)

		# 5) イベントアニメーション
		var played: bool = await _execute_event(event, old_positions, snapshot)
		if not played:
			await _delay(EVENT_DELAY)

		# 6) 安全弁 + 状態更新
		_reveal_all(hidden)
		_prev_cs = snapshot

	# 7) 最終補正
	if cs_final != null and refresh_fn.is_valid():
		refresh_fn.call(cs_final)
	_prev_cs = cs_final


func _process_actions_cue(entry: Dictionary) -> void:
	var actions: Array = entry.get("actions", [])
	if on_actions_ready.is_valid():
		on_actions_ready.call(actions)


func _process_banner_cue(entry: Dictionary) -> void:
	var scene: PackedScene = entry.get("banner_scene")
	if scene == null:
		return
	var banner: Control = scene.instantiate()
	_anim_layer.add_child(banner)
	await banner.play()


# ===========================================================================
# イベント演出
# ===========================================================================

func _execute_event(event: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> bool:
	var event_type: String = event.get("type", "")
	var player: int = event.get("player", -1)
	var is_me: bool = cs != null and (player == cs.my_player)

	match event_type:
		"TURN_START":
			return await _cue_turn_start(is_me)
		"DRAW":
			return await _cue_draw(event, is_me, old_positions)
		"PLAY_CARD":
			return await _cue_play_card(event, is_me, old_positions)
		"SKILL_EFFECT":
			return await _cue_skill_effect(event, is_me, old_positions)

	return false


# ===========================================================================
# 個別演出
# ===========================================================================

func _cue_turn_start(is_me: bool) -> bool:
	var banner: TurnStartBanner = _TurnStartBannerScene.instantiate()
	banner.set_text("MY TURN" if is_me else "OP TURN")
	_anim_layer.add_child(banner)
	await banner.play()
	return true


func _cue_draw(event: Dictionary, is_me: bool,
		old_positions: Dictionary) -> bool:
	var from_xform: Dictionary = old_positions.get("deck", {})
	if from_xform.is_empty():
		return false

	if is_me:
		var card_data: Dictionary = event.get("card", {})
		if card_data.is_empty():
			return false
		var iid: int = card_data.get("instance_id", -1)
		var to_xform: Dictionary = hand.get_card_content_transform(iid)
		if to_xform.is_empty():
			return false
		hand.hide_card(iid)
		await _fly_card({"instance_id": iid, "hidden": true}, false,
			from_xform, to_xform, FLY_DURATION)
		hand.show_card(iid)
	else:
		var to_xform: Dictionary = _get_opp_hand_center()
		await _fly_card({"instance_id": -9999, "hidden": true}, false,
			from_xform, to_xform, FLY_DURATION)

	return true


func _cue_play_card(event: Dictionary, is_me: bool,
		old_positions: Dictionary) -> bool:
	var card_data: Dictionary = event.get("card", {})
	if card_data.is_empty():
		return false
	var iid: int = card_data.get("instance_id", -1)

	var to_xform: Dictionary = card_layer.get_card_content_transform(iid)
	if to_xform.is_empty():
		return false

	var from_xform: Dictionary
	var fly_data: Dictionary
	var fly_face_up: bool

	if is_me:
		from_xform = old_positions.get(iid, {})
		if from_xform.is_empty():
			return false
		fly_data = card_data
		fly_face_up = not card_data.get("face_down", false)
	else:
		from_xform = _get_opp_hand_center()
		fly_data = card_data
		fly_face_up = false

	card_layer.hide_card(iid)
	await _fly_card(fly_data, fly_face_up, from_xform, to_xform, FLY_DURATION)
	card_layer.show_card(iid)

	return true


func _cue_skill_effect(event: Dictionary, is_me: bool,
		old_positions: Dictionary) -> bool:
	# 1) カットイン演出
	var skill_name: String = event.get("skill_name", "")
	var nickname: String = event.get("nickname", "")
	if not skill_name.is_empty():
		var cutin: SkillCutIn = _SkillCutInScene.instantiate()
		cutin.setup(skill_name, nickname, is_me)
		_anim_layer.add_child(cutin)
		await cutin.play()

	# 2) 移動アニメーション
	var moves: Array = event.get("moves", [])
	for move in moves:
		if _cancelled:
			break
		await _cue_card_move(move, old_positions)

	# 3) フリップアニメーション
	var flips: Array = event.get("flips", [])
	for flip in flips:
		if _cancelled:
			break
		await _cue_card_flip(flip)

	return not skill_name.is_empty() or not moves.is_empty() or not flips.is_empty()


func _cue_card_move(move: Dictionary, old_positions: Dictionary) -> void:
	var iid: int = move.get("instance_id", -1)
	var card_data: Dictionary = move.get("card", {})
	var from_zone: String = move.get("from_zone", "")
	var to_zone: String = move.get("to_zone", "")
	var style: String = move.get("style", "DEFAULT")

	# from: old_positions にあればそれを使う（移動前のスナップショット）
	var from_xform: Dictionary = old_positions.get(iid, {})
	if from_xform.is_empty():
		from_xform = old_positions.get(from_zone, {})
	if from_xform.is_empty():
		return

	# to: 現在の UI 上の位置（refresh 後）
	var to_xform: Dictionary = _get_zone_position(to_zone, iid)
	if to_xform.is_empty():
		return

	# 到着先のカードを一時非表示（飛行中に重複表示を防ぐ）
	var hide_in_hand: bool = (to_zone == "hand")
	var hide_in_field: bool = (to_zone == "stage" or to_zone == "backstage")

	if hide_in_hand:
		hand.hide_card(iid)
	if hide_in_field:
		card_layer.hide_card(iid)

	var face_up: bool = not card_data.get("face_down", false) \
		and not card_data.get("hidden", false)

	match style:
		_:
			await _fly_card(card_data, face_up, from_xform, to_xform, FLY_DURATION)

	if hide_in_hand:
		hand.show_card(iid)
	if hide_in_field:
		card_layer.show_card(iid)


## フリップアニメーションを一括実行（プレースホルダー作成 + アニメ + show）。
func _cue_card_flip(flip: Dictionary) -> void:
	var iid: int = flip.get("instance_id", -1)
	var card_data: Dictionary = flip.get("card", {})
	var to_face_down: bool = flip.get("to_face_down", false)

	var xform: Dictionary = card_layer.get_card_content_transform(iid)
	if xform.is_empty():
		return

	# プレースホルダー作成（旧面で表示）
	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(card_data, to_face_down)  # フリップ前の面
	cv.position = xform.get("pos", Vector2.ZERO)
	cv.scale = xform.get("scale", Vector2.ONE)
	cv.rotation = xform.get("rotation", 0.0)
	_anim_layer.add_child(cv)

	var base_scale_x: float = xform.get("scale", Vector2.ONE).x
	var half: float = FLIP_DURATION / 2.0

	# 前半: scale.x → 0（カードが閉じる）
	var tween1: Tween = cv.create_tween()
	tween1.tween_property(cv, "scale:x", 0.0, half) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween1.finished

	# フリップ後の面に切り替え
	cv.setup(card_data, not to_face_down)

	# 後半: scale.x → 元の値（カードが開く）
	var tween2: Tween = cv.create_tween()
	tween2.tween_property(cv, "scale:x", base_scale_x, half) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween2.finished

	cv.queue_free()
	card_layer.show_card(iid)


func _get_zone_position(zone: String, instance_id: int) -> Dictionary:
	match zone:
		"deck":
			return deck_view.get_card_content_transform()
		"home":
			return home_view.get_card_content_transform()
		"hand":
			var xform: Dictionary = hand.get_card_content_transform(instance_id)
			if not xform.is_empty():
				return xform
			return _get_opp_hand_center()
		"stage", "backstage":
			return card_layer.get_card_content_transform(instance_id)
	return {}


# ===========================================================================
# アニメーション・プリミティブ
# ===========================================================================

func _fly_card(card_data: Dictionary, face_up: bool,
		from_xform: Dictionary, to_xform: Dictionary,
		duration: float) -> void:
	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(card_data, face_up)

	cv.position = from_xform.get("pos", Vector2.ZERO)
	cv.scale = from_xform.get("scale", Vector2.ONE)
	cv.rotation = from_xform.get("rotation", 0.0)

	_anim_layer.add_child(cv)

	var to_pos: Vector2 = to_xform.get("pos", Vector2.ZERO)
	var to_scale: Vector2 = to_xform.get("scale", Vector2.ONE)
	var to_rotation: float = to_xform.get("rotation", 0.0)

	var tween: Tween = cv.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cv, "position", to_pos, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cv, "scale", to_scale, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cv, "rotation", to_rotation, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	cv.queue_free()


func _delay(seconds: float) -> void:
	await _anim_layer.get_tree().create_timer(seconds).timeout


# ===========================================================================
# ゾーン変化カードの自動非表示
# ===========================================================================

## prev_cs と new_cs の各ゾーンを比較し、新たに到着した instance_id や
## face_down が変わったカードを非表示にして返す。
func _hide_changed_cards(old_cs: ClientState, new_cs: ClientState) -> Array:
	var old_hand_ids: Dictionary = {}
	var old_field_ids: Dictionary = {}
	var old_field_face_down: Dictionary = {}  # instance_id -> face_down

	if old_cs != null:
		for card_data in old_cs.my_hand:
			old_hand_ids[card_data.get("instance_id", -1)] = true
		for p in range(2):
			for card_data in old_cs.stages[p]:
				var iid: int = card_data.get("instance_id", -1)
				old_field_ids[iid] = true
				old_field_face_down[iid] = card_data.get("face_down", false)
			if old_cs.backstages[p] != null:
				var iid: int = old_cs.backstages[p].get("instance_id", -1)
				old_field_ids[iid] = true
				old_field_face_down[iid] = old_cs.backstages[p].get("face_down", false)

	if new_cs == null:
		return []

	var hidden: Array = []

	# 手札に新たに到着したカードを非表示
	for card_data in new_cs.my_hand:
		var iid: int = card_data.get("instance_id", -1)
		if not old_hand_ids.has(iid):
			hand.hide_card(iid)
			hidden.append(iid)

	# フィールド（ステージ・楽屋）に新たに到着 or face_down が変わったカードを非表示
	for p in range(2):
		for card_data in new_cs.stages[p]:
			var iid: int = card_data.get("instance_id", -1)
			var new_fd: bool = card_data.get("face_down", false)
			if not old_field_ids.has(iid) or old_field_face_down.get(iid, new_fd) != new_fd:
				card_layer.hide_card(iid)
				hidden.append(iid)
		if new_cs.backstages[p] != null:
			var iid: int = new_cs.backstages[p].get("instance_id", -1)
			var new_fd: bool = new_cs.backstages[p].get("face_down", false)
			if not old_field_ids.has(iid) or old_field_face_down.get(iid, new_fd) != new_fd:
				card_layer.hide_card(iid)
				hidden.append(iid)

	return hidden


## アニメーションで表示されなかったカードの安全弁。
## 各 _cue_* メソッドは既に show_card() を呼んでいるため、正常時は冪等。
func _reveal_all(hidden_ids: Array) -> void:
	for iid in hidden_ids:
		hand.show_card(iid)
		card_layer.show_card(iid)


# ===========================================================================
# ヘルパー
# ===========================================================================

func _capture_positions(cs: ClientState) -> Dictionary:
	var result: Dictionary = {}

	# デッキ・ホーム位置は cs に依存しないので常にキャプチャ
	result["deck"] = deck_view.get_card_content_transform()
	result["home"] = home_view.get_card_content_transform()

	if cs == null:
		return result

	# 手札
	for card_data in cs.my_hand:
		var iid: int = card_data.get("instance_id", -1)
		var xform: Dictionary = hand.get_card_content_transform(iid)
		if not xform.is_empty():
			result[iid] = xform

	# フィールド (ステージ + 楽屋)
	for p in range(2):
		for card_data in cs.stages[p]:
			var iid: int = card_data.get("instance_id", -1)
			var xform: Dictionary = card_layer.get_card_content_transform(iid)
			if not xform.is_empty():
				result[iid] = xform
		if cs.backstages[p] != null:
			var iid: int = cs.backstages[p].get("instance_id", -1)
			var xform: Dictionary = card_layer.get_card_content_transform(iid)
			if not xform.is_empty():
				result[iid] = xform

	return result


func _get_opp_hand_center() -> Dictionary:
	return {
		"pos": opp_hand.position + PIVOT * opp_hand.scale - PIVOT,
		"scale": opp_hand.scale,
		"rotation": 0.0,
	}

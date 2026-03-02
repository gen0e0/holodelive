class_name StagingDirector
extends RefCounted

## 演出キューシステム。
## state_updated / actions_received をキューに積み、await ベースで直列処理する。
## CPUターンの同期再帰で複数シグナルが1フレーム内に発火しても、
## アニメーションが順序通り再生される。

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
var _queue: Array = []          # [{type, cs?, events?, actions?}]
var _processing: bool = false
var _prev_cs: ClientState       # 前回の ClientState（位置キャプチャ用）
var _cancelled: bool = false
var _flip_placeholders: Dictionary = {}  # instance_id -> entry Dictionary


func _init(anim_layer: Control) -> void:
	_anim_layer = anim_layer


# ===========================================================================
# 公開 API
# ===========================================================================

## state_updated 受信時に呼ぶ。
func enqueue_state_update(cs: ClientState, events: Array) -> void:
	_queue.append({
		"type": _CueType.STATE_UPDATE,
		"cs": cs,
		"events": events,
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
	var cs: ClientState = entry.get("cs")
	var events: Array = entry.get("events", [])

	# 1) 現在の視覚状態をスナップショット（前のキューの refresh 結果が反映済み）
	var old_positions: Dictionary = _capture_positions(_prev_cs)

	# 2) UI を新しい状態に即更新
	if refresh_fn.is_valid():
		refresh_fn.call(cs)

	# 3) ゾーン移動・フリップカードを非表示にする（アニメーション前に見えてしまうのを防ぐ）
	var hidden_ids: Array = _hide_zone_arrivals(_prev_cs, cs)

	# 4) フリップ対象のプレースホルダーを即座に作成（先行イベント中も旧面で表示）
	_flip_placeholders = {}
	for event in events:
		if event.get("type", "") == "SKILL_EFFECT":
			for flip in event.get("flips", []):
				var fe: Dictionary = _prepare_card_flip(flip)
				if not fe.is_empty():
					_flip_placeholders[fe.get("iid", -1)] = fe

	# 5) トークン消滅検知（_prev_cs を更新する前に比較）
	var consumed_keys: Array = []
	if _prev_cs != null:
		consumed_keys = field_layout.get_consumed_token_keys(
			_prev_cs.field_effects, cs.field_effects)

	_prev_cs = cs

	# 6) トークン消滅アニメーション
	for key in consumed_keys:
		if _cancelled:
			break
		await field_layout.play_consume_animation(key)

	# 7) イベント列をアニメーション化
	await _stage_events(events, old_positions, cs)

	# 8) アニメーションで表示されなかったカードの安全弁
	_reveal_all(hidden_ids)


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

func _stage_events(events: Array, old_positions: Dictionary,
		cs: ClientState) -> void:
	for event in events:
		if _cancelled:
			break
		var played: bool = await _execute_event(event, old_positions, cs)
		if not played:
			# アニメなしイベントには小ウェイトを入れて視覚的区切りを作る
			await _delay(EVENT_DELAY)


func _execute_event(event: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> bool:
	var event_type: String = event.get("type", "")
	var player: int = event.get("player", -1)
	var is_me: bool = (player == cs.my_player)

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
	# 1) 事前作成済みのフリッププレースホルダーを取得
	var flips: Array = event.get("flips", [])
	var flip_entries: Array = []
	for flip in flips:
		var iid: int = flip.get("instance_id", -1)
		if _flip_placeholders.has(iid):
			flip_entries.append(_flip_placeholders[iid])
			_flip_placeholders.erase(iid)

	# 2) カットイン演出
	var skill_name: String = event.get("skill_name", "")
	var nickname: String = event.get("nickname", "")
	if not skill_name.is_empty():
		var cutin: SkillCutIn = _SkillCutInScene.instantiate()
		cutin.setup(skill_name, nickname, is_me)
		_anim_layer.add_child(cutin)
		await cutin.play()

	# 3) 移動アニメーション
	var moves: Array = event.get("moves", [])
	for move in moves:
		if _cancelled:
			break
		await _cue_card_move(move, old_positions)

	# 4) フリップアニメーション
	for entry in flip_entries:
		if _cancelled:
			break
		await _animate_card_flip(entry)

	return not skill_name.is_empty() or not moves.is_empty() or not flip_entries.is_empty()


func _cue_card_move(move: Dictionary, old_positions: Dictionary) -> void:
	var iid: int = move.get("instance_id", -1)
	var card_data: Dictionary = move.get("card", {})
	var from_zone: String = move.get("from_zone", "")
	var to_zone: String = move.get("to_zone", "")

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
	await _fly_card(card_data, face_up, from_xform, to_xform, FLY_DURATION)

	if hide_in_hand:
		hand.show_card(iid)
	if hide_in_field:
		card_layer.show_card(iid)


## フリッププレースホルダーを作成。実カードは _hide_zone_arrivals で既に非表示。
## 旧面の一時カードを同じ位置に配置し、カットイン中も見えるようにする。
func _prepare_card_flip(flip: Dictionary) -> Dictionary:
	var iid: int = flip.get("instance_id", -1)
	var card_data: Dictionary = flip.get("card", {})
	var to_face_down: bool = flip.get("to_face_down", false)

	var xform: Dictionary = card_layer.get_card_content_transform(iid)
	if xform.is_empty():
		return {}

	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(card_data, to_face_down)  # フリップ前の面（to_face_down=true→表, =false→裏）
	cv.position = xform.get("pos", Vector2.ZERO)
	cv.scale = xform.get("scale", Vector2.ONE)
	cv.rotation = xform.get("rotation", 0.0)
	_anim_layer.add_child(cv)

	return {
		"cv": cv,
		"iid": iid,
		"card_data": card_data,
		"to_face_down": to_face_down,
		"base_scale_x": xform.get("scale", Vector2.ONE).x,
	}


## プレースホルダーのフリップアニメーションを実行。
func _animate_card_flip(entry: Dictionary) -> void:
	var cv: CardView = entry.get("cv")
	var iid: int = entry.get("iid", -1)
	var card_data: Dictionary = entry.get("card_data", {})
	var to_face_down: bool = entry.get("to_face_down", false)
	var base_scale_x: float = entry.get("base_scale_x", 1.0)

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
# ゾーン到着カードの自動非表示
# ===========================================================================

## prev_cs と new_cs の各ゾーンを比較し、新たに到着した instance_id や
## face_down が変わったカードを非表示にして返す。
func _hide_zone_arrivals(old_cs: ClientState, new_cs: ClientState) -> Array:
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

class_name StagingDirector
extends RefCounted

## 演出キューシステム（前方再生方式）。
## state_updated / actions_received をキューに積み、await ベースで直列処理する。
## イベントを1つずつ処理: アニメーション（旧UI上で実行）→ スナップショットでUI更新。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const _TurnStartBannerScene: PackedScene = preload("res://scenes/gui/animation/turn_start_banner.tscn")
const _SkillCutInScene: PackedScene = preload("res://scenes/gui/animation/skill_cutin.tscn")
const FLY_DURATION: float = 0.35
const EVENT_DELAY: float = 0.15
const PIVOT: Vector2 = Vector2(150, 210)  # CardView の pivot_offset
const SPIN_OUT_DURATION: float = 0.6
const SPIN_OUT_JUMP_HEIGHT: float = 120.0  # ジャンプの高さ (px)
const MAX_SKILL_DURATION: float = 2.0     # スキル演出の最大待ち時間

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

## STATE_UPDATE キュー処理完了後に呼ばれるコールバック: func() -> void
## アニメーション完了 → refresh 後に保留中のインタラクション（choice / actions）を発火するために使う。
var on_state_processed: Callable

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

		# 2) イベントアニメーション（旧UIのまま実行）
		var played: bool = await _execute_event(event, old_positions, snapshot)
		if not played:
			await _delay(EVENT_DELAY)

		# 3) トークン消滅アニメーション（旧UIに残っているので問題なし）
		if _prev_cs != null and snapshot != null:
			var consumed: Array = field_layout.get_consumed_token_keys(
				_prev_cs.field_effects, snapshot.field_effects)
			for key in consumed:
				if _cancelled:
					break
				await field_layout.play_consume_animation(key)

		# 4) UI更新（アニメーション後）
		if refresh_fn.is_valid() and snapshot != null:
			refresh_fn.call(snapshot)

		_prev_cs = snapshot

	# 7) 最終補正
	if cs_final != null and refresh_fn.is_valid():
		refresh_fn.call(cs_final)
	_prev_cs = cs_final

	# 8) 保留中のインタラクションを発火
	if on_state_processed.is_valid():
		on_state_processed.call()


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
			return await _cue_draw(event, is_me, old_positions, cs)
		"PLAY_CARD":
			return await _cue_play_card(event, is_me, old_positions, cs)
		"SKILL_EFFECT":
			return await _cue_skill_effect(event, is_me, old_positions, cs)

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
		old_positions: Dictionary, cs: ClientState) -> bool:
	var from_xform: Dictionary = old_positions.get("deck", {})
	if from_xform.is_empty():
		return false

	if is_me:
		var card_data: Dictionary = event.get("card", {})
		if card_data.is_empty():
			return false
		var to_xform: Dictionary = _get_hand_center(hand)
		await _fly_card(card_data, false,
			from_xform, to_xform, FLY_DURATION)
	else:
		var to_xform: Dictionary = _get_hand_center(opp_hand)
		await _fly_card({"instance_id": -9999, "hidden": true}, false,
			from_xform, to_xform, FLY_DURATION)

	return true


func _cue_play_card(event: Dictionary, is_me: bool,
		old_positions: Dictionary, cs: ClientState) -> bool:
	var card_data: Dictionary = event.get("card", {})
	if card_data.is_empty():
		return false
	var iid: int = card_data.get("instance_id", -1)
	var to_zone: String = event.get("to_zone", "stage")

	var to_xform: Dictionary = _compute_to_xform(to_zone, iid, cs)
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
		hand.hide_card(iid)
	else:
		from_xform = _get_hand_center(opp_hand)
		fly_data = card_data
		fly_face_up = false

	await _fly_card(fly_data, fly_face_up, from_xform, to_xform, FLY_DURATION)

	return true


func _cue_skill_effect(event: Dictionary, is_me: bool,
		old_positions: Dictionary, cs: ClientState) -> bool:
	var cues: Array = event.get("cues", [])

	# 1) カットイン演出（await で先に完了させる）
	# カットイン中もフィールドのカードはそのまま旧面で見える（プレースホルダー不要）
	var skill_name: String = event.get("skill_name", "")
	var nickname: String = event.get("nickname", "")
	if not skill_name.is_empty():
		var cutin: SkillCutIn = _SkillCutInScene.instantiate()
		cutin.setup(skill_name, nickname, is_me)
		_anim_layer.add_child(cutin)
		await cutin.play()

	# 2) find_card + move の移動元カードを一括非表示
	for cue_dict in cues:
		if cue_dict.get("action", "") == "move" and cue_dict.get("source", "") == "find":
			_hide_cue_source(cue_dict, old_positions, cs)

	# 3) 全キューを fire-and-forget で同時発火
	var anim_items: Array = []  # Node（自己廃棄型）と Tween の混在
	for cue_dict in cues:
		var cue_action: String = cue_dict.get("action", "")
		if cue_action == "move":
			var node: CardView = _fire_cue_move(cue_dict, old_positions, cs)
			if node != null:
				anim_items.append(node)
		elif cue_action == "flip":
			var tween: Tween = _fire_cue_flip(cue_dict)
			if tween != null:
				anim_items.append(tween)

	# 4) 全完了 or タイムアウト待ち
	if not anim_items.is_empty():
		var max_dur: float = event.get("max_animation_duration", MAX_SKILL_DURATION)
		await _wait_for_animations(anim_items, max_dur)

	return not skill_name.is_empty() or not cues.is_empty()


## find_card の移動元カードを非表示にする。
func _hide_cue_source(cue_dict: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> void:
	var iid: int = cue_dict.get("instance_id", -1)
	var from_zone: String = cue_dict.get("from_zone", "auto")

	if from_zone == "auto":
		# old_positions に iid があればフィールド/手札上のカード
		if old_positions.has(iid):
			# 手札かフィールドかを判定して非表示
			if _is_my_card_in_hand(iid, _prev_cs):
				hand.hide_card(iid)
			else:
				card_layer.hide_card(iid)
	elif from_zone == "hand":
		var from_player: int = cue_dict.get("from_player", -1)
		if from_player >= 0 and cs != null and from_player == cs.my_player:
			hand.hide_card(iid)
		# 相手手札は個別カード非表示不要（中心座標からアニメーション）
	elif from_zone == "stage" or from_zone == "backstage":
		card_layer.hide_card(iid)


## move キューを fire-and-forget で発火。自己廃棄する CardView を返す。
func _fire_cue_move(cue_dict: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> CardView:
	var iid: int = cue_dict.get("instance_id", -1)
	var card_data: Dictionary = cue_dict.get("card", {})
	var style: String = cue_dict.get("style", "DEFAULT")
	var delay: float = cue_dict.get("delay", 0.0)
	var dur: float = cue_dict.get("duration", -1.0)

	var from_xform: Dictionary = _resolve_from(cue_dict, old_positions, cs)
	if from_xform.is_empty():
		return null

	var to_xform: Dictionary = _resolve_to(cue_dict, cs)
	if to_xform.is_empty():
		return null

	# face_up: 明示指定 > カードの face_down 状態
	var face_up_val: Variant = cue_dict.get("face_up", null)
	var face_up: bool
	if face_up_val != null:
		face_up = face_up_val as bool
	else:
		face_up = not card_data.get("face_down", false) \
			and not card_data.get("hidden", false)

	if dur < 0:
		dur = SPIN_OUT_DURATION if style == "SPIN_OUT" else FLY_DURATION

	match style:
		"SPIN_OUT":
			return _fire_spin_out_card(card_data, face_up, from_xform, to_xform, delay)
		_:
			return _fire_fly_card(card_data, face_up, from_xform, to_xform, dur, delay)
	return null


## from ゾーンを画面座標に解決する。
func _resolve_from(cue_dict: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> Dictionary:
	var iid: int = cue_dict.get("instance_id", -1)
	var from_zone: String = cue_dict.get("from_zone", "auto")
	var from_player: int = cue_dict.get("from_player", -1)

	if from_zone == "auto":
		# old_positions から iid で検索
		var xform: Dictionary = old_positions.get(iid, {})
		if not xform.is_empty():
			return xform
		# フォールバック: opp_hand 中心
		return old_positions.get("opp_hand", {})

	# ゾーン指定で解決を試みる
	var result: Dictionary = _resolve_zone_xform(
		from_zone, from_player, iid, cs, old_positions)
	# stage/backstage は新 cs では既に移動済みの場合がある → old_positions にフォールバック
	if result.is_empty() and old_positions.has(iid):
		return old_positions[iid]
	return result


## to ゾーンを画面座標に解決する。
func _resolve_to(cue_dict: Dictionary, cs: ClientState) -> Dictionary:
	var iid: int = cue_dict.get("instance_id", -1)
	var to_zone: String = cue_dict.get("to_zone", "")
	var to_player: int = cue_dict.get("to_player", -1)

	return _resolve_zone_xform(to_zone, to_player, iid, cs, {})


## ゾーン名 + player → 画面座標。
func _resolve_zone_xform(zone: String, player: int, iid: int,
		cs: ClientState, old_positions: Dictionary) -> Dictionary:
	match zone:
		"deck":
			return deck_view.get_card_content_transform()
		"home":
			return home_view.get_card_content_transform()
		"hand":
			if cs != null and player == cs.my_player:
				return _get_hand_center(hand)
			return _get_hand_center(opp_hand)
		"stage":
			# snapshot から iid のスロットを検索
			return _find_field_slot_xform(iid, cs, true)
		"backstage":
			return _find_field_slot_xform(iid, cs, false)
	return {}


## flip キューを実カードの CardView.play_flip() で発火。Tween を返す。
func _fire_cue_flip(cue_dict: Dictionary) -> Tween:
	var iid: int = cue_dict.get("instance_id", -1)
	var card_data: Dictionary = cue_dict.get("card", {})
	var p_to_face_down: bool = cue_dict.get("to_face_down", false)
	var delay: float = cue_dict.get("delay", 0.0)

	var cv: CardView = card_layer.get_card_view(iid)
	if cv == null:
		return null

	return cv.play_flip(not p_to_face_down, card_data, delay)


func _get_hand_center(h: HandZone) -> Dictionary:
	return {
		"pos": h.position + PIVOT * h.scale - PIVOT,
		"scale": h.scale,
		"rotation": 0.0,
	}


func _compute_to_xform(to_zone: String, iid: int, cs: ClientState) -> Dictionary:
	match to_zone:
		"deck":
			return deck_view.get_card_content_transform()
		"home":
			return home_view.get_card_content_transform()
		"hand":
			return _get_hand_center(hand if _is_my_card_in_hand(iid, cs) else opp_hand)
		"stage":
			return _find_field_slot_xform(iid, cs, true)
		"backstage":
			return _find_field_slot_xform(iid, cs, false)
	return {}


func _is_my_card_in_hand(iid: int, cs: ClientState) -> bool:
	if cs == null:
		return false
	for card_data in cs.my_hand:
		if card_data.get("instance_id", -1) == iid:
			return true
	return false


func _find_field_slot_xform(iid: int, cs: ClientState, is_stage: bool) -> Dictionary:
	if cs == null:
		return {}
	for p in range(2):
		if is_stage:
			var stage: Array = cs.stages[p]
			for i in range(stage.size()):
				if stage[i].get("instance_id", -1) == iid:
					var slot: SlotMarker = field_layout.get_stage_slot(p, i)
					return card_layer.get_slot_content_transform(slot)
		else:
			var bs: Variant = cs.backstages[p]
			if bs != null and bs.get("instance_id", -1) == iid:
				var slot: SlotMarker = field_layout.get_backstage_slot(p)
				return card_layer.get_slot_content_transform(slot)
	return {}


# ===========================================================================
# fire-and-forget アニメーション（スキル演出用、自己廃棄型）
# ===========================================================================

func _fire_fly_card(card_data: Dictionary, face_up: bool,
		from_xform: Dictionary, to_xform: Dictionary,
		duration: float, delay: float) -> CardView:
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
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
	tween.tween_property(cv, "scale", to_scale, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
	tween.tween_property(cv, "rotation", to_rotation, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
	tween.finished.connect(cv.queue_free)
	return cv


func _fire_spin_out_card(card_data: Dictionary, face_up: bool,
		from_xform: Dictionary, to_xform: Dictionary, delay: float) -> CardView:
	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(card_data, face_up)

	var from_pos: Vector2 = from_xform.get("pos", Vector2.ZERO)
	cv.position = from_pos
	cv.scale = from_xform.get("scale", Vector2.ONE)
	cv.rotation = from_xform.get("rotation", 0.0)
	cv.pivot_offset = PIVOT
	_anim_layer.add_child(cv)

	var to_pos: Vector2 = to_xform.get("pos", Vector2.ZERO)
	var to_scale: Vector2 = to_xform.get("scale", Vector2.ONE)

	var tween: Tween = cv.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cv, "position:x", to_pos.x, SPIN_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
	tween.tween_method(
		func(t: float) -> void:
			var linear_y: float = lerpf(from_pos.y, to_pos.y, t)
			var arc: float = 4.0 * SPIN_OUT_JUMP_HEIGHT * t * (1.0 - t)
			cv.position.y = linear_y - arc,
		0.0, 1.0, SPIN_OUT_DURATION
	).set_delay(delay)
	tween.tween_property(cv, "rotation", TAU, SPIN_OUT_DURATION) \
		.set_trans(Tween.TRANS_LINEAR).set_delay(delay)
	tween.tween_property(cv, "scale", to_scale, SPIN_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
	tween.finished.connect(cv.queue_free)
	return cv


## 全アニメーションの完了またはタイムアウトを待つ。
## items は Node（自己廃棄型）と Tween（既存カード上）の混在可。
## タイムアウト時は残存ノードを強制廃棄、Tween を強制停止する。
func _wait_for_animations(items: Array, max_duration: float) -> void:
	var timer: SceneTreeTimer = _anim_layer.get_tree().create_timer(max_duration)
	while timer.time_left > 0.0:
		var all_done: bool = true
		for item in items:
			if not is_instance_valid(item):
				continue
			if item is Node:
				all_done = false
				break
			elif item is Tween:
				if item.is_running():
					all_done = false
					break
		if all_done or _cancelled:
			break
		await _anim_layer.get_tree().process_frame
	for item in items:
		if not is_instance_valid(item):
			continue
		if item is Node:
			item.queue_free()
		elif item is Tween and item.is_running():
			item.kill()


# ===========================================================================
# await 型アニメーション・プリミティブ（DRAW / PLAY_CARD 用）
# ===========================================================================

func _spin_out_card(card_data: Dictionary, face_up: bool,
		from_xform: Dictionary, to_xform: Dictionary) -> void:
	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(card_data, face_up)

	var from_pos: Vector2 = from_xform.get("pos", Vector2.ZERO)
	cv.position = from_pos
	cv.scale = from_xform.get("scale", Vector2.ONE)
	cv.rotation = from_xform.get("rotation", 0.0)
	cv.pivot_offset = PIVOT

	_anim_layer.add_child(cv)

	var to_pos: Vector2 = to_xform.get("pos", Vector2.ZERO)
	var to_scale: Vector2 = to_xform.get("scale", Vector2.ONE)

	var tween: Tween = cv.create_tween()
	tween.set_parallel(true)

	# X: スムーズ移動
	tween.tween_property(cv, "position:x", to_pos.x, SPIN_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Y: 放物線アーク (直線補間 + 上向きオフセット)
	tween.tween_method(
		func(t: float) -> void:
			var linear_y: float = lerpf(from_pos.y, to_pos.y, t)
			var arc: float = 4.0 * SPIN_OUT_JUMP_HEIGHT * t * (1.0 - t)
			cv.position.y = linear_y - arc,
		0.0, 1.0, SPIN_OUT_DURATION
	)

	# 回転: 1回転 (TAU = 2π)
	tween.tween_property(cv, "rotation", TAU, SPIN_OUT_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)

	# スケール
	tween.tween_property(cv, "scale", to_scale, SPIN_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	cv.queue_free()


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
# ヘルパー
# ===========================================================================

func _capture_positions(cs: ClientState) -> Dictionary:
	var result: Dictionary = {}

	# ゾーン中心位置（個別カードが見つからない場合のフォールバック）
	result["deck"] = deck_view.get_card_content_transform()
	result["home"] = home_view.get_card_content_transform()
	result["my_hand"] = _get_hand_center(hand)
	result["opp_hand"] = _get_hand_center(opp_hand)

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

class_name StagingDirector
extends RefCounted

## 演出キューシステム（前方再生方式）。
## state_updated / actions_received をキューに積み、await ベースで直列処理する。
## イベントを1つずつ処理: アニメーション（旧UI上で実行）→ スナップショットでUI更新。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const _TurnStartBannerScene: PackedScene = preload("res://scenes/gui/animation/turn_start_banner.tscn")
const _SkillCutInScene: PackedScene = preload("res://scenes/gui/animation/skill_cutin.tscn")
const FLY_DURATION: float = 0.35
const FLIP_DURATION: float = 0.3
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
	var flips: Array = event.get("flips", [])
	var moves: Array = event.get("moves", [])

	# 0) フリッププレースホルダー事前作成（カットイン中も旧面で表示）
	var flip_entries: Array = []
	for flip in flips:
		var fe: Dictionary = _create_flip_placeholder(flip)
		if not fe.is_empty():
			fe["delay"] = flip.get("delay", 0.0)
			flip_entries.append(fe)

	# 1) カットイン演出（await で先に完了させる）
	var skill_name: String = event.get("skill_name", "")
	var nickname: String = event.get("nickname", "")
	if not skill_name.is_empty():
		var cutin: SkillCutIn = _SkillCutInScene.instantiate()
		cutin.setup(skill_name, nickname, is_me)
		_anim_layer.add_child(cutin)
		await cutin.play()

	# 2) 移動元カードを一括非表示（発火前に全部隠す）
	for move in moves:
		_hide_move_source(move)

	# 3) 全 move/flip を fire-and-forget で同時発火
	var anim_nodes: Array = []
	for move in moves:
		var node: CardView = _fire_card_move(move, old_positions, cs)
		if node != null:
			anim_nodes.append(node)
	for fe in flip_entries:
		var node: CardView = _fire_flip_animation(fe)
		if node != null:
			anim_nodes.append(node)

	# 4) 全完了 or タイムアウト待ち
	if not anim_nodes.is_empty():
		var max_dur: float = event.get("max_animation_duration", MAX_SKILL_DURATION)
		await _wait_for_animations(anim_nodes, max_dur)

	return not skill_name.is_empty() or not moves.is_empty() or not flip_entries.is_empty()


## 移動元カードを非表示にする（アニメーション発火前に一括呼び出し用）。
func _hide_move_source(move: Dictionary) -> void:
	var iid: int = move.get("instance_id", -1)
	var from_zone: String = move.get("from_zone", "")
	if from_zone == "hand":
		hand.hide_card(iid)
	elif from_zone == "stage" or from_zone == "backstage":
		card_layer.hide_card(iid)


## move を fire-and-forget で発火。自己廃棄する CardView を返す。
func _fire_card_move(move: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> CardView:
	var iid: int = move.get("instance_id", -1)
	var card_data: Dictionary = move.get("card", {})
	var from_zone: String = move.get("from_zone", "")
	var to_zone: String = move.get("to_zone", "")
	var style: String = move.get("style", "DEFAULT")
	var delay: float = move.get("delay", 0.0)

	var from_xform: Dictionary = old_positions.get(iid, {})
	if from_xform.is_empty():
		# 自分の手札は個別位置あり。見つからない "hand" は相手手札
		if from_zone == "hand":
			from_xform = old_positions.get("opp_hand", {})
		else:
			from_xform = old_positions.get(from_zone, {})
	if from_xform.is_empty():
		return null

	var to_xform: Dictionary = _compute_to_xform(to_zone, iid, cs)
	if to_xform.is_empty():
		return null

	var face_up: bool = not card_data.get("face_down", false) \
		and not card_data.get("hidden", false)

	match style:
		"SPIN_OUT":
			return _fire_spin_out_card(card_data, face_up, from_xform, to_xform, delay)
		_:
			return _fire_fly_card(card_data, face_up, from_xform, to_xform, FLY_DURATION, delay)
	return null


## フリッププレースホルダーを作成。旧面の一時カードを同じ位置に配置し、
## 実カードを非表示にする。カットイン中も旧面が見えるよう、アニメーション前に呼ぶ。
func _create_flip_placeholder(flip: Dictionary) -> Dictionary:
	var iid: int = flip.get("instance_id", -1)
	var card_data: Dictionary = flip.get("card", {})
	var to_face_down: bool = flip.get("to_face_down", false)

	var xform: Dictionary = card_layer.get_card_content_transform(iid)
	if xform.is_empty():
		return {}

	# プレースホルダーが代わりに表示するので実カードは非表示
	card_layer.hide_card(iid)

	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(card_data, to_face_down)  # フリップ前の面
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


## フリップアニメーションを fire-and-forget で発火。自己廃棄する CardView を返す。
func _fire_flip_animation(entry: Dictionary) -> CardView:
	var cv: CardView = entry.get("cv")
	var card_data: Dictionary = entry.get("card_data", {})
	var to_face_down: bool = entry.get("to_face_down", false)
	var base_scale_x: float = entry.get("base_scale_x", 1.0)
	var delay: float = entry.get("delay", 0.0)

	var half: float = FLIP_DURATION / 2.0

	var tween: Tween = cv.create_tween()
	# 前半: scale.x → 0（カードが閉じる）
	tween.tween_property(cv, "scale:x", 0.0, half) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(delay)
	# フリップ後の面に切り替え
	tween.tween_callback(func() -> void: cv.setup(card_data, not to_face_down))
	# 後半: scale.x → 元の値（カードが開く）
	tween.tween_property(cv, "scale:x", base_scale_x, half) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(cv.queue_free)
	return cv


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


## 全アニメーションノードの完了またはタイムアウトを待つ。
## タイムアウト時は残存ノードを強制廃棄する。
func _wait_for_animations(nodes: Array, max_duration: float) -> void:
	var timer: SceneTreeTimer = _anim_layer.get_tree().create_timer(max_duration)
	while timer.time_left > 0.0:
		var all_freed: bool = true
		for node in nodes:
			if is_instance_valid(node):
				all_freed = false
				break
		if all_freed or _cancelled:
			break
		await _anim_layer.get_tree().process_frame
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()


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

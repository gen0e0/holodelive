class_name StagingDirector
extends RefCounted

## 演出キューシステム（前方再生方式）。
## state_updated / actions_received をキューに積み、await ベースで直列処理する。
## イベントを1つずつ処理: アニメーション（旧UI上で実行）→ スナップショットでUI更新。

const _TurnStartBannerScene: PackedScene = preload("res://scenes/gui/animation/turn_start_banner.tscn")
const _SkillCutInScene: PackedScene = preload("res://scenes/gui/animation/skill_cutin.tscn")
const FLY_DURATION: float = 0.35
const EVENT_DELAY: float = 0.15
const PIVOT: Vector2 = Vector2(150, 210)  # CardView の pivot_offset
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


func is_processing() -> bool:
	return _processing


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

	# AnimationLayer 上の一時ノードを全削除
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
			GameLog.log_event("UI", "refresh")
			refresh_fn.call(snapshot)

		_prev_cs = snapshot

	# 最終補正
	if cs_final != null and refresh_fn.is_valid():
		refresh_fn.call(cs_final)
	_prev_cs = cs_final

	# 保留中のインタラクションを発火
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
	GameLog.log_event("STAGING", event_type, {"player": player})

	match event_type:
		"TURN_START":
			return await _cue_turn_start(is_me)
		"DRAW":
			return await _cue_draw(event, is_me, old_positions)
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
		old_positions: Dictionary) -> bool:
	var from_xform: Dictionary = old_positions.get("deck", {})
	if from_xform.is_empty():
		return false

	var card_data: Dictionary
	if is_me:
		card_data = event.get("card", {})
		if card_data.is_empty():
			return false
	else:
		card_data = {"instance_id": -9999, "hidden": true}

	var to_xform: Dictionary = _get_hand_center(hand if is_me else opp_hand)
	var anim: FlyCardAnim = FlyCardAnim.create(card_data, false,
		from_xform, to_xform, FLY_DURATION)
	_anim_layer.add_child(anim)
	await anim.finished
	return true


func _cue_play_card(event: Dictionary, is_me: bool,
		old_positions: Dictionary, cs: ClientState) -> bool:
	var card_data: Dictionary = event.get("card", {})
	if card_data.is_empty():
		return false
	var iid: int = card_data.get("instance_id", -1)
	var to_zone: String = event.get("to_zone", "stage")

	var to_xform: Dictionary = _resolve_zone_xform(to_zone, -1, iid, cs, {})
	if to_xform.is_empty():
		return false

	var from_xform: Dictionary
	var fly_face_up: bool

	if is_me:
		from_xform = old_positions.get(iid, {})
		if from_xform.is_empty():
			return false
		fly_face_up = not card_data.get("face_down", false)
		hand.hide_card(iid)
	else:
		from_xform = _get_hand_center(opp_hand)
		fly_face_up = false

	GameLog.log_event("ANIM", "play_card_start", {"iid": iid, "to": to_zone, "is_me": is_me})
	var anim: FlyCardAnim = FlyCardAnim.create(card_data, fly_face_up,
		from_xform, to_xform, FLY_DURATION)
	_anim_layer.add_child(anim)
	await anim.finished
	GameLog.log_event("ANIM", "play_card_end", {"iid": iid})
	return true


func _cue_skill_effect(event: Dictionary, is_me: bool,
		old_positions: Dictionary, cs: ClientState) -> bool:
	var cues: Array = event.get("cues", [])

	# 1) カットイン演出（await で先に完了させる）
	var skill_name: String = event.get("skill_name", "")
	var nickname: String = event.get("nickname", "")
	if not skill_name.is_empty():
		GameLog.log_event("ANIM", "cutin_start", {"skill": skill_name, "nickname": nickname})
		var cutin: SkillCutIn = _SkillCutInScene.instantiate()
		cutin.setup(skill_name, nickname, is_me)
		_anim_layer.add_child(cutin)
		await cutin.play()
		GameLog.log_event("ANIM", "cutin_end", {"skill": skill_name})

	# 2) find_card + move の移動元カードを一括非表示
	for cue_dict in cues:
		if cue_dict.get("action", "") == "move" and cue_dict.get("source", "") == "find":
			_hide_cue_source(cue_dict, old_positions, cs)

	# 3) 全キューを fire-and-forget で同時発火
	var anim_nodes: Array = []  # Node（自己廃棄型）と Tween の混在
	for cue_dict in cues:
		var cue_action: String = cue_dict.get("action", "")
		var cue_iid: int = cue_dict.get("instance_id", -1)
		if cue_action == "move":
			GameLog.log_event("ANIM", "move_start", {
				"iid": cue_iid,
				"from": cue_dict.get("from_zone", "?"),
				"to": cue_dict.get("to_zone", "?"),
			})
			var node: Node = _fire_cue_move(cue_dict, old_positions, cs)
			if node != null:
				anim_nodes.append(node)
			else:
				GameLog.log_event("ANIM", "move_skip", {"iid": cue_iid, "reason": "resolve_failed"})
		elif cue_action == "flip":
			GameLog.log_event("ANIM", "flip_start", {"iid": cue_iid})
			var tween: Tween = _fire_cue_flip(cue_dict)
			if tween != null:
				anim_nodes.append(tween)
		elif cue_action == "shuffle":
			GameLog.log_event("ANIM", "shuffle_start", {})
			var node: Node = _fire_cue_shuffle(cue_dict, cs)
			if node != null:
				anim_nodes.append(node)

	# 4) 全完了 or タイムアウト待ち
	if not anim_nodes.is_empty():
		GameLog.log_event("ANIM", "await_all", {"count": anim_nodes.size()})
		var max_dur: float = _dur(event.get("max_animation_duration", MAX_SKILL_DURATION))
		await _wait_for_animations(anim_nodes, max_dur)
		GameLog.log_event("ANIM", "await_done")

	return not skill_name.is_empty() or not cues.is_empty()


## find_card の移動元カードを非表示にする。
func _hide_cue_source(cue_dict: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> void:
	var iid: int = cue_dict.get("instance_id", -1)
	var from_zone: String = cue_dict.get("from_zone", "auto")

	if from_zone == "auto":
		if old_positions.has(iid):
			if _is_my_card_in_hand(iid, _prev_cs):
				hand.hide_card(iid)
			else:
				card_layer.hide_card(iid)
	elif from_zone == "hand":
		var from_player: int = cue_dict.get("from_player", -1)
		if from_player >= 0 and cs != null and from_player == cs.my_player:
			hand.hide_card(iid)
		elif from_player >= 0 and cs != null and from_player != cs.my_player:
			opp_hand.hide_card(iid)
	elif from_zone == "stage" or from_zone == "backstage":
		card_layer.hide_card(iid)


## move キューを fire-and-forget で発火。自己廃棄する Node を返す。
func _fire_cue_move(cue_dict: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> Node:
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

	var anim: Node
	if style == "SPIN_OUT":
		anim = SpinOutCardAnim.create(card_data, face_up, from_xform, to_xform, delay)
	else:
		if dur < 0:
			dur = FLY_DURATION
		anim = FlyCardAnim.create(card_data, face_up, from_xform, to_xform, dur, delay)

	_anim_layer.add_child(anim)
	return anim


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


# ===========================================================================
# ゾーン → 画面座標 解決
# ===========================================================================

## from ゾーンを画面座標に解決する。
func _resolve_from(cue_dict: Dictionary, old_positions: Dictionary,
		cs: ClientState) -> Dictionary:
	var iid: int = cue_dict.get("instance_id", -1)
	var from_zone: String = cue_dict.get("from_zone", "auto")
	var from_player: int = cue_dict.get("from_player", -1)

	if from_zone == "auto":
		var xform: Dictionary = old_positions.get(iid, {})
		if not xform.is_empty():
			return xform
		return old_positions.get("opp_hand", {})

	var result: Dictionary = _resolve_zone_xform(
		from_zone, from_player, iid, cs, old_positions)
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
		"center":
			return {"pos": Vector2(810, 340), "scale": Vector2(0.6, 0.6), "rotation": 0.0}
		"deck":
			return deck_view.get_card_content_transform()
		"home":
			return home_view.get_card_content_transform()
		"hand":
			if cs != null and player == cs.my_player:
				return _get_hand_center(hand)
			# player 未指定の場合は iid で判定
			if player < 0 and _is_my_card_in_hand(iid, cs):
				return _get_hand_center(hand)
			return _get_hand_center(opp_hand)
		"stage":
			return _find_field_slot_xform(iid, cs, true, player)
		"backstage":
			return _find_field_slot_xform(iid, cs, false, player)
	return {}


func _get_hand_center(h: HandZone) -> Dictionary:
	return {
		"pos": h.position + PIVOT * h.scale - PIVOT,
		"scale": h.scale,
		"rotation": 0.0,
	}


func _is_my_card_in_hand(iid: int, cs: ClientState) -> bool:
	if cs == null:
		return false
	for card_data in cs.my_hand:
		if card_data.get("instance_id", -1) == iid:
			return true
	return false


func _find_field_slot_xform(iid: int, cs: ClientState, is_stage: bool, filter_player: int = -1) -> Dictionary:
	if cs == null:
		return {}
	for p in range(2):
		if filter_player >= 0 and p != filter_player:
			continue
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
# シャッフル演出
# ===========================================================================

## 裏向きカード2枚を画面中央で上下にバウンスさせるシャッフル演出。
## 自己破棄型 Node を返す。
func _fire_cue_shuffle(cue_dict: Dictionary, cs: ClientState = null) -> Node:
	var center_pos := Vector2(810, 340)
	var card_scale := Vector2(0.6, 0.6)
	# to_zone が指定されていればその位置でシャッフル
	var to_zone: String = cue_dict.get("to_zone", "")
	if to_zone != "" and cs != null:
		var to_player: int = cue_dict.get("to_player", -1)
		var xf: Dictionary = _resolve_zone_xform(to_zone, to_player, -1, cs, {})
		if not xf.is_empty():
			center_pos = xf.get("pos", center_pos)
			card_scale = xf.get("scale", card_scale)
	var bounce_dist: float = 80.0
	var bounce_count: int = cue_dict.get("bounce_count", 3)
	var delay_sec: float = cue_dict.get("delay", 0.0)

	# コンテナ（自己破棄型）
	var container := Node2D.new()
	_anim_layer.add_child(container)

	# 裏向きカード2枚を生成
	var _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
	var cv_top: CardView = _CardViewScene.instantiate()
	cv_top.managed_hover = true
	cv_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv_top.setup({}, false)  # 裏向き
	cv_top.scale = card_scale
	cv_top.position = center_pos + Vector2(-20, -10)
	cv_top.rotation_degrees = -5.0
	container.add_child(cv_top)

	var cv_bottom: CardView = _CardViewScene.instantiate()
	cv_bottom.managed_hover = true
	cv_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv_bottom.setup({}, false)
	cv_bottom.scale = card_scale
	cv_bottom.position = center_pos + Vector2(20, 10)
	cv_bottom.rotation_degrees = 5.0
	container.add_child(cv_bottom)

	# バウンスアニメーション
	var tw: Tween = container.create_tween()
	if delay_sec > 0.0:
		tw.tween_interval(_dur(delay_sec))
	for i in range(bounce_count):
		# 上のカードを上に、下のカードを下に
		tw.tween_property(cv_top, "position:y", center_pos.y - bounce_dist - 10, _dur(0.15)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(cv_bottom, "position:y", center_pos.y + bounce_dist + 10, _dur(0.15)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# 戻す
		tw.tween_property(cv_top, "position:y", center_pos.y - 10, _dur(0.15)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(cv_bottom, "position:y", center_pos.y + 10, _dur(0.15)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# フェードアウト
	tw.tween_property(container, "modulate:a", 0.0, _dur(0.2))
	tw.finished.connect(func() -> void: container.queue_free())

	return container


# ===========================================================================
# アニメーション完了待ち
# ===========================================================================

## 全アニメーションの完了またはタイムアウトを待つ。
## items は Node（自己廃棄型、finished シグナル持ち）と Tween の混在可。
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
# ユーティリティ
# ===========================================================================

func _dur(seconds: float) -> float:
	var s: float = GameConfig.animation_speed
	if s <= 0.0:
		return 0.0
	return seconds / s


func _delay(seconds: float) -> void:
	var d: float = _dur(seconds)
	if d <= 0.0:
		await _anim_layer.get_tree().process_frame
		return
	await _anim_layer.get_tree().create_timer(d).timeout


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

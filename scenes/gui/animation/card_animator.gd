class_name CardAnimator
extends RefCounted

## カード移動アニメーションのオーケストレーター。
## AnimationLayer 上に一時的な CardView を生成し、Tween で移動させる。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const FLY_DURATION: float = 0.35
const PIVOT: Vector2 = Vector2(150, 210)  # CardView の pivot_offset

var _anim_layer: Control
var _active_tweens: Array = []
var _hidden_cards: Array = []  # [{zone, instance_id}]


func _init(anim_layer: Control) -> void:
	_anim_layer = anim_layer


func capture_positions(hand: HandZone, opp_hand: HandZone, card_layer: CardLayer,
		deck: DeckView, home: HomeView, cs: ClientState) -> Dictionary:
	var result: Dictionary = {}

	# デッキ・ホーム位置は cs に依存しないので常にキャプチャ
	result["deck"] = deck.get_card_content_transform()
	result["home"] = home.get_card_content_transform()

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


func animate_events(events: Array, old_positions: Dictionary,
		hand: HandZone, opp_hand: HandZone, card_layer: CardLayer,
		deck: DeckView, home: HomeView,
		field_layout: FieldLayout, cs: ClientState) -> bool:
	var animated: bool = false

	for event in events:
		var event_type: String = event.get("type", "")
		var player: int = event.get("player", -1)
		var is_me: bool = (player == cs.my_player)

		match event_type:
			"DRAW":
				animated = _animate_draw(event, is_me, old_positions,
					hand, opp_hand) or animated
			"PLAY_CARD":
				animated = _animate_play(event, is_me, old_positions,
					hand, opp_hand, card_layer) or animated

	return animated


func cancel_all() -> void:
	for tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

	# 隠したカードを復元
	for entry in _hidden_cards:
		var zone: Variant = entry.get("zone")
		var iid: int = entry.get("instance_id", -1)
		if zone is HandZone:
			zone.show_card(iid)
		elif zone is CardLayer:
			zone.show_card(iid)
	_hidden_cards.clear()

	# AnimationLayer 上の一時カードを全削除
	for child in _anim_layer.get_children():
		child.queue_free()


# ---------------------------------------------------------------------------
# 個別アニメーション
# ---------------------------------------------------------------------------

func _animate_draw(event: Dictionary, is_me: bool, old_positions: Dictionary,
		hand: HandZone, opp_hand: HandZone) -> bool:
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
		_hidden_cards.append({"zone": hand, "instance_id": iid})
		_fly_card({"instance_id": iid, "hidden": true}, false,
			from_xform, to_xform, FLY_DURATION,
			func() -> void:
				hand.show_card(iid)
				_remove_hidden_entry(hand, iid)
		)
	else:
		var to_xform: Dictionary = _get_opp_hand_center(opp_hand)
		_fly_card({"instance_id": -9999, "hidden": true}, false,
			from_xform, to_xform, FLY_DURATION, Callable())

	return true


func _animate_play(event: Dictionary, is_me: bool, old_positions: Dictionary,
		hand: HandZone, opp_hand: HandZone, card_layer: CardLayer) -> bool:
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
		from_xform = _get_opp_hand_center(opp_hand)
		fly_data = card_data
		fly_face_up = false

	card_layer.hide_card(iid)
	_hidden_cards.append({"zone": card_layer, "instance_id": iid})

	_fly_card(fly_data, fly_face_up, from_xform, to_xform, FLY_DURATION,
		func() -> void:
			card_layer.show_card(iid)
			_remove_hidden_entry(card_layer, iid)
	)

	return true


# ---------------------------------------------------------------------------
# ヘルパー
# ---------------------------------------------------------------------------

func _fly_card(card_data: Dictionary, face_up: bool,
		from_xform: Dictionary, to_xform: Dictionary,
		duration: float, on_complete: Callable) -> void:
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

	_active_tweens.append(tween)

	tween.chain().tween_callback(func() -> void:
		cv.queue_free()
		_active_tweens.erase(tween)
		if on_complete.is_valid():
			on_complete.call()
	)


func _get_opp_hand_center(opp_hand: HandZone) -> Dictionary:
	return {
		"pos": opp_hand.position + PIVOT * opp_hand.scale - PIVOT,
		"scale": opp_hand.scale,
		"rotation": 0.0,
	}


func _remove_hidden_entry(zone: Variant, iid: int) -> void:
	for i in range(_hidden_cards.size() - 1, -1, -1):
		var entry: Dictionary = _hidden_cards[i]
		if entry.get("zone") == zone and entry.get("instance_id") == iid:
			_hidden_cards.remove_at(i)
			break

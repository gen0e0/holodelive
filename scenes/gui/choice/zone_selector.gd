class_name ZoneSelector
extends ChoiceHandler

## ゾーン選択UI（SELECT_ZONE 用）。
## ステージ / 楽屋などの選択肢をボタンで表示する。
## ui_hint == "play_preview" の場合、プレイフェーズ風のUIを表示する。

var _ui_parent: Control
var _hand_zone: HandZone
var _field_layout: FieldLayout
var _buttons: Array = []
var _preview_card: CardView = null
var _choice_index: int = 0
var _active: bool = false

const _ZONE_LABELS: Dictionary = {
	"stage": "ステージ",
	"backstage": "楽屋",
}

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")


func _init(ui_parent: Control, hand_zone: HandZone = null, field_layout: FieldLayout = null) -> void:
	_ui_parent = ui_parent
	_hand_zone = hand_zone
	_field_layout = field_layout


func can_handle(choice_data: Dictionary) -> bool:
	return choice_data.get("choice_type", -1) == Enums.ChoiceType.SELECT_ZONE


func activate(choice_data: Dictionary) -> void:
	_choice_index = choice_data.get("choice_index", 0)
	var targets: Array = choice_data.get("valid_targets", [])
	var ui_hint: String = choice_data.get("ui_hint", "")
	_active = true

	if ui_hint.begins_with("play_preview"):
		_activate_play_preview(targets, choice_data)
	else:
		_activate_default(targets)


func _activate_default(targets: Array) -> void:
	var x: float = 320.0
	for zone in targets:
		var label: String = _ZONE_LABELS.get(zone, str(zone))
		var btn: OverlayButton = OverlayButton.create(label, Rect2(x, 430, 200, 60))
		btn.visible = true
		btn.pressed.connect(_on_zone_pressed.bind(zone))
		_ui_parent.add_child(btn)
		_buttons.append(btn)
		x += 220.0


func _activate_play_preview(targets: Array, choice_data: Dictionary) -> void:
	# プレビュー用カード情報があれば HandZone のショーケースと同じ位置に表示
	var card_data: Dictionary = choice_data.get("preview_card", {})
	if not card_data.is_empty() and card_data.has("card_id"):
		_preview_card = _CardViewScene.instantiate()
		_preview_card.managed_hover = true
		_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_card.setup(card_data, true)
		if _hand_zone != null:
			_preview_card.position = _hand_zone.position + _hand_zone.showcase_offset
			_preview_card.scale = Vector2(_hand_zone.showcase_scale, _hand_zone.showcase_scale)
		else:
			_preview_card.position = Vector2(1160, 500)
			_preview_card.scale = Vector2(1.3, 1.3)
		_ui_parent.add_child(_preview_card)

	# プレイフェーズと同じボタンレイアウト（FieldLayout から位置取得）
	var stage_rect: Rect2 = _get_stage_rect()
	var bs_rect: Rect2 = _get_backstage_rect()
	for zone in targets:
		if zone == "stage":
			var btn: OverlayButton = OverlayButton.create(
				"ステージにプレイ", stage_rect)
			btn.visible = true
			btn.pressed.connect(_on_zone_pressed.bind("stage"))
			_ui_parent.add_child(btn)
			_buttons.append(btn)
		elif zone == "backstage":
			var btn: OverlayButton = OverlayButton.create(
				"楽屋にプレイ", bs_rect)
			btn.visible = true
			btn.pressed.connect(_on_zone_pressed.bind("backstage"))
			_ui_parent.add_child(btn)
			_buttons.append(btn)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()
	if _preview_card != null:
		_preview_card.queue_free()
		_preview_card = null


func _on_zone_pressed(zone: String) -> void:
	if not _active:
		return
	resolved.emit(_choice_index, zone)


func _get_stage_rect() -> Rect2:
	if _field_layout:
		var my_p: int = _field_layout.my_player
		var s3: SlotMarker = _field_layout.get_stage_slot(my_p, 2)
		var s1: SlotMarker = _field_layout.get_stage_slot(my_p, 0)
		if s3 and s1:
			var left_top: Vector2 = _to_overlay_local(s3, Vector2.ZERO)
			var right_bottom: Vector2 = _to_overlay_local(s1, s1.size)
			return Rect2(left_top, right_bottom - left_top)
	return Rect2(84, 80, 864, 392)


func _get_backstage_rect() -> Rect2:
	if _field_layout:
		var bs: SlotMarker = _field_layout.get_backstage_slot(_field_layout.my_player)
		if bs:
			var pos: Vector2 = _to_overlay_local(bs, Vector2.ZERO)
			var end: Vector2 = _to_overlay_local(bs, bs.size)
			return Rect2(pos, end - pos)
	return Rect2(668, 500, 280, 392)


func _to_overlay_local(node: Control, offset: Vector2) -> Vector2:
	var global_pos: Vector2 = node.global_position + offset * node.get_global_transform().get_scale()
	return _ui_parent.get_global_transform().affine_inverse() * global_pos

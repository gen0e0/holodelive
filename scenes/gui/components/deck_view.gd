class_name DeckView
extends Control

## デッキ表示コンポーネント。裏向きカードに枚数を重ねて表示する。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const CARD_SCALE: float = 0.5

var _card_view: CardView
var _count_label: Label


func _ready() -> void:
	_card_view = _CardViewScene.instantiate()
	_card_view.managed_hover = true
	_card_view.scale = Vector2(CARD_SCALE, CARD_SCALE)
	add_child(_card_view)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.size = Vector2(150, 210)
	_count_label.add_theme_font_size_override("font_size", 48)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_count_label.add_theme_constant_override("shadow_offset_x", 2)
	_count_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_count_label)


func update_count(count: int) -> void:
	if count > 0:
		_card_view.setup({"instance_id": -2000, "hidden": true}, false)
		_card_view.visible = true
		_count_label.text = str(count)
		_count_label.visible = true
	else:
		_card_view.visible = false
		_count_label.visible = false

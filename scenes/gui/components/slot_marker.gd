class_name SlotMarker
extends Control

enum SlotType { HAND, STAGE, BACKSTAGE, DECK, HOME }

const MY_BG := Color(0.2, 0.35, 0.55, 0.3)
const MY_BORDER := Color(0.3, 0.5, 0.7, 0.4)
const OPP_BG := Color(0.55, 0.2, 0.25, 0.3)
const OPP_BORDER := Color(0.7, 0.3, 0.35, 0.4)

@export var slot_type: SlotType = SlotType.HAND
@export var player: int = 0
@export var slot_index: int = 0

@onready var _background: Panel = get_node_or_null("Background")
@onready var _slot_label: Label = get_node_or_null("SlotLabel")


func _ready() -> void:
	_update_visuals()


func _update_visuals() -> void:
	if _background:
		var style: StyleBoxFlat = _background.get_theme_stylebox("panel").duplicate()
		var bg_color: Color = MY_BG if player == 0 else OPP_BG
		var border_color: Color = MY_BORDER if player == 0 else OPP_BORDER
		style.bg_color = bg_color
		style.border_color = border_color
		_background.add_theme_stylebox_override("panel", style)
	if _slot_label:
		match slot_type:
			SlotType.STAGE:
				_slot_label.text = "STAGE %d" % (slot_index + 1)
			SlotType.BACKSTAGE:
				_slot_label.text = "BACKSTAGE"
			_:
				_slot_label.text = ""

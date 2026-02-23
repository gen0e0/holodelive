class_name SlotMarker
extends Control

enum SlotType { HAND, STAGE, BACKSTAGE, DECK, HOME }

@export var slot_type: SlotType = SlotType.HAND
@export var player: int = 0
@export var slot_index: int = 0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(1, 1, 1, 0.15), false, 1.0)

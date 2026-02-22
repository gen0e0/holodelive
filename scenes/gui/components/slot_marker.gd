class_name SlotMarker
extends Control

enum SlotType { HAND, STAGE, BACKSTAGE, DECK, HOME }

@export var slot_type: SlotType = SlotType.HAND
@export var player: int = 0
@export var slot_index: int = 0

const CARD_WIDTH: int = 120
const CARD_HEIGHT: int = 168


func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(1, 1, 1, 0.15), false, 1.0)

class_name CardInstance
extends RefCounted

var instance_id: int = 0
var card_id: int = 0
var face_down: bool = false
var action_skill_used: bool = false
var modifiers: Array = []  # Array[Modifier]

func _init(p_instance_id: int = 0, p_card_id: int = 0) -> void:
	instance_id = p_instance_id
	card_id = p_card_id

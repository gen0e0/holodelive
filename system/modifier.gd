class_name Modifier
extends RefCounted

var type: Enums.ModifierType = Enums.ModifierType.ICON_ADD
var value: String = ""
var source_instance_id: int = -1
var persistent: bool = false

func _init(p_type: Enums.ModifierType = Enums.ModifierType.ICON_ADD, p_value: String = "", p_source: int = -1, p_persistent: bool = false) -> void:
	type = p_type
	value = p_value
	source_instance_id = p_source
	persistent = p_persistent

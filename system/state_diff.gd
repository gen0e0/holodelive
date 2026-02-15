class_name StateDiff
extends RefCounted

var type: Enums.DiffType = Enums.DiffType.PROPERTY_CHANGE
var details: Dictionary = {}

func _init(p_type: Enums.DiffType = Enums.DiffType.PROPERTY_CHANGE, p_details: Dictionary = {}) -> void:
	type = p_type
	details = p_details

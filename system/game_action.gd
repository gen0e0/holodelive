class_name GameAction
extends RefCounted

var type: Enums.ActionType = Enums.ActionType.DRAW
var player: int = 0
var params: Dictionary = {}
var diffs: Array = []  # Array[StateDiff]

func _init(p_type: Enums.ActionType = Enums.ActionType.DRAW, p_player: int = 0, p_params: Dictionary = {}) -> void:
	type = p_type
	player = p_player
	params = p_params

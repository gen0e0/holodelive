class_name SkillStackEntry
extends RefCounted

var card_id: int = -1
var skill_index: int = 0
var source_instance_id: int = -1
var player: int = 0
var phase: int = 0
var data: Dictionary = {}
var targets: Array = []
var state: Enums.SkillState = Enums.SkillState.PENDING

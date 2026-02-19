class_name PendingChoice
extends RefCounted

var stack_index: int = -1
var skill_source_instance_id: int = -1
var target_player: int = 0
var choice_type: Enums.ChoiceType = Enums.ChoiceType.SELECT_CARD
var valid_targets: Array = []
var timeout: float = 30.0
var timeout_strategy: String = "first"
var resolved: bool = false
var result: Variant = null

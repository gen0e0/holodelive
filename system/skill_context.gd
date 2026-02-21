class_name SkillContext
extends RefCounted

var state: GameState
var registry: CardRegistry
var recorder: DiffRecorder
var skill_registry: SkillRegistry
var source_instance_id: int = -1
var player: int = 0
var phase: int = 0
var choice_result: Variant = null
var data: Dictionary = {}


func _init(
	p_state: GameState = null,
	p_registry: CardRegistry = null,
	p_source_instance_id: int = -1,
	p_player: int = 0,
	p_phase: int = 0,
	p_choice_result: Variant = null,
	p_recorder: DiffRecorder = null,
	p_skill_registry: SkillRegistry = null
) -> void:
	state = p_state
	registry = p_registry
	source_instance_id = p_source_instance_id
	player = p_player
	phase = p_phase
	choice_result = p_choice_result
	recorder = p_recorder
	skill_registry = p_skill_registry

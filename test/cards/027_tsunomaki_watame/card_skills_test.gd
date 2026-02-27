extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/027_tsunomaki_watame/card_skills.gd") as GDScript).new()


func test_027_watame_no_stage_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(27, "わため", ["VOCAL"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(27, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 27)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(27).execute_skill(ctx, 0)

	assert_bool(state.has_field_effect("no_stage_play", 1)).is_true()
	assert_int(state.field_effects.size()).is_equal(1)
	var fe: FieldEffect = state.field_effects[0]
	assert_str(fe.type).is_equal("no_stage_play")
	assert_int(fe.target_player).is_equal(1)
	assert_int(fe.source_instance_id).is_equal(inst_id)

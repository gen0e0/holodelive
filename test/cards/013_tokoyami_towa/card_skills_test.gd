extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/013_tokoyami_towa/card_skills.gd") as GDScript).new()


func test_013_towa_protection() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(13, "トワ", ["CHARISMA"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(13, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 13)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(13).execute_skill(ctx, 0)

	assert_bool(state.has_field_effect("protection", 0)).is_true()
	assert_int(state.field_effects.size()).is_equal(1)
	var fe: FieldEffect = state.field_effects[0]
	assert_str(fe.type).is_equal("protection")
	assert_int(fe.target_player).is_equal(0)
	assert_int(fe.source_instance_id).is_equal(inst_id)
	assert_int(fe.lifetime).is_equal(1)

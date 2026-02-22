extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/039_irys/card_skills.gd") as GDScript).new()


func test_039_irys_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(39, "IRyS", ["SEISO"], ["ENGLISH"], [H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(39, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 39)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(39).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("WILD")

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/061_nerissa_ravencroft/card_skills.gd") as GDScript).new()


func test_061_nerissa_sexy() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(61, "ネリッサ", ["VOCAL", "SEXY"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(93, "SEXY_card", ["SEXY"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(61, _load_skill())

	var sexy_id: int = H.place_on_stage(state, 1, 93)
	var inst_id: int = H.place_on_stage(state, 0, 61)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(61).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, sexy_id, DiffRecorder.new())
	result = sr.get_skill(61).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(sexy_id)).is_true()

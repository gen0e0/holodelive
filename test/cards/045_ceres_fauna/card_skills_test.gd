extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/045_ceres_fauna/card_skills.gd") as GDScript).new()


func test_045_fauna_steal_kusogaki() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(45, "ファウナ", ["INTEL", "SEISO"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(94, "KG_card", ["KUSOGAKI"], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(45, _load_skill())

	var kg_id: int = H.place_on_stage(state, 1, 94)
	var inst_id: int = H.place_on_stage(state, 0, 45)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(45).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, kg_id, DiffRecorder.new())
	result = sr.get_skill(45).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(kg_id)).is_true()
	assert_bool(state.stages[1].has(kg_id)).is_false()


func test_045_fauna_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(45, "ファウナ", ["INTEL"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(94, "KG_card", ["KUSOGAKI"], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(45, _load_skill())

	H.place_on_stage(state, 1, 94)
	H.place_on_stage(state, 0, 45)
	H.place_on_stage(state, 0, 45)
	var inst_id: int = H.place_on_stage(state, 0, 45)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(45).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/047_hakos_baelz/card_skills.gd") as GDScript).new()


func test_047_baelz_swap_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(47, "ベールズ", ["KUSOGAKI"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(47, _load_skill())

	var opp_card: int = H.place_on_stage(state, 1, 47)
	var inst_id: int = H.place_on_stage(state, 0, 47)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(47).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(47).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[1].has(inst_id)).is_true()
	assert_bool(state.stages[0].has(opp_card)).is_true()


func test_047_baelz_no_target() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(47, "ベールズ", ["KUSOGAKI"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(47, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 47)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(47).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

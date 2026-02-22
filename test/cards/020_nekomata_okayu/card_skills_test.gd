extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/020_nekomata_okayu/card_skills.gd") as GDScript).new()


func test_020_okayu_win() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(20, "おかゆ", ["SEXY", "VOCAL"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(20, _load_skill())

	var opp_first: int = H.place_on_stage(state, 1, 20)
	var inst_id: int = H.place_on_stage(state, 0, 20)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 5, DiffRecorder.new())
	ctx.data = {"my_roll": 5}
	result = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 3, DiffRecorder.new())
	ctx.data = {"my_roll": 5}
	result = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(opp_first)).is_true()


func test_020_okayu_lose() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(20, "おかゆ", ["SEXY", "VOCAL"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(20, _load_skill())

	H.place_on_stage(state, 1, 20)
	var inst_id: int = H.place_on_stage(state, 0, 20)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(20).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 2, DiffRecorder.new())
	ctx.data = {"my_roll": 2}
	sr.get_skill(20).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 5, DiffRecorder.new())
	ctx.data = {"my_roll": 2}
	var result: SkillResult = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(inst_id)).is_true()

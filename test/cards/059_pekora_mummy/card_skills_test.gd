extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/059_pekora_mummy/card_skills.gd") as GDScript).new()


func test_059_mummy_three_wins() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(59, "マミー", [], [], [H.passive_skill()]),
		H.make_card_def(99, "OPP", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(59, _load_skill())

	var opp1: int = H.place_on_stage(state, 1, 99)
	var opp2: int = H.place_on_stage(state, 1, 99)
	var opp3: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 59)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 1, DiffRecorder.new())
	ctx.data = {"wins": 1}
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 1, DiffRecorder.new())
	ctx.data = {"wins": 2}
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 3, 1, DiffRecorder.new())
	ctx.data = {"wins": 3}
	var result: SkillResult = sr.get_skill(59).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp1)).is_true()
	assert_bool(state.home.has(opp2)).is_true()
	assert_bool(state.home.has(opp3)).is_true()
	assert_bool(state.removed.has(inst_id)).is_true()


func test_059_mummy_no_wins() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(59, "マミー", [], [], [H.passive_skill()]),
		H.make_card_def(99, "OPP", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(59, _load_skill())

	var opp1: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 59)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 0, DiffRecorder.new())
	ctx.data = {"wins": 0}
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 0, DiffRecorder.new())
	ctx.data = {"wins": 0}
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 3, 0, DiffRecorder.new())
	ctx.data = {"wins": 0}
	var result: SkillResult = sr.get_skill(59).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[1].has(opp1)).is_true()
	assert_bool(state.removed.has(inst_id)).is_true()

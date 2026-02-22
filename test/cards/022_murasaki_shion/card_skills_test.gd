extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/022_murasaki_shion/card_skills.gd") as GDScript).new()


func test_022_shion_redistribute() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(22, "シオン", ["KUSOGAKI"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(22, _load_skill())

	var my1: int = H.place_in_hand(state, 0, 22)
	var my2: int = H.place_in_hand(state, 0, 22)
	var opp1: int = H.place_in_hand(state, 1, 22)
	var inst_id: int = H.place_on_stage(state, 0, 22)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(22).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	var saved_data: Dictionary = ctx.data.duplicate(true)
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	ctx.data = saved_data
	result = sr.get_skill(22).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(2)
	assert_int(state.hands[1].size()).is_equal(1)


func test_022_shion_both_empty() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(22, "シオン", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(22, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 22)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(22).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

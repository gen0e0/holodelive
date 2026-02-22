extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/036_yagoo/card_skills.gd") as GDScript).new()


func test_036_yagoo_steal_two() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(36, "YAGOO", [], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(36, _load_skill())

	var opp1: int = H.place_in_hand(state, 1, 36)
	var opp2: int = H.place_in_hand(state, 1, 36)
	var opp3: int = H.place_in_hand(state, 1, 36)
	var inst_id: int = H.place_on_stage(state, 0, 36)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(36).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(36).execute_skill(ctx, 0)
	assert_bool(state.hands[0].has(opp1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp3, DiffRecorder.new())
	result = sr.get_skill(36).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(opp3)).is_true()
	assert_int(state.hands[1].size()).is_equal(1)
	assert_bool(state.hands[1].has(opp2)).is_true()


func test_036_yagoo_opponent_one_card() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(36, "YAGOO", [], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(36, _load_skill())

	H.place_in_hand(state, 1, 36)
	var inst_id: int = H.place_on_stage(state, 0, 36)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(36).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[1].size()).is_equal(1)

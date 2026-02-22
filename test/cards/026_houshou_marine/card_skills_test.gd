extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/026_houshou_marine/card_skills.gd") as GDScript).new()


func test_026_marine_steal_and_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(26, "マリン", ["OTAKU", "SEXY"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(26, _load_skill())

	var opp_card: int = H.place_on_stage(state, 1, 26)
	var my_hand: int = H.place_in_hand(state, 0, 26)
	var inst_id: int = H.place_on_stage(state, 0, 26)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(26).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(26).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp_card)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, my_hand, DiffRecorder.new())
	result = sr.get_skill(26).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.backstages[0]).is_equal(my_hand)

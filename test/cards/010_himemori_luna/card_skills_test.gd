extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/010_himemori_luna/card_skills.gd") as GDScript).new()


func test_010_luna_random_discard() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(10, "ルーナ", ["ALCOHOL", "SEISO"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var controller: GameController = env.controller
	var sr: SkillRegistry = env.skill_registry
	sr.register(10, _load_skill())

	var opp_card: int = H.place_in_hand(state, 1, 10)
	var inst_id: int = H.place_on_stage(state, 0, 10)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(10).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(result.choice_type).is_equal(Enums.ChoiceType.RANDOM_RESULT)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(10).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(opp_card)).is_false()
	assert_bool(state.home.has(opp_card)).is_true()


func test_010_luna_empty_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(10, "ルーナ", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(10, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 10)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(10).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

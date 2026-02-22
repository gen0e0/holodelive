extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/046_ouro_kronii/card_skills.gd") as GDScript).new()


func test_046_kronii_self_home_opp_two_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(46, "クロニー", ["ALCOHOL", "SEXY"], ["INDONESIA"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(46, _load_skill())

	var opp1: int = H.place_on_stage(state, 1, 46)
	var opp2: int = H.place_on_stage(state, 1, 46)
	var inst_id: int = H.place_on_stage(state, 0, 46)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(46).execute_skill(ctx, 0)
	assert_bool(state.home.has(inst_id)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	result = sr.get_skill(46).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp2, DiffRecorder.new())
	result = sr.get_skill(46).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(opp2)).is_true()

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/006_amane_kanata/card_skills.gd") as GDScript).new()


func test_006_kanata_to_deck_top() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(6, "かなた", ["REACTION"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(6, _load_skill())

	var opp_card: int = H.place_on_stage(state, 1, 6)
	var inst_id: int = H.place_on_stage(state, 0, 6)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(6).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(opp_card)).is_true()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(6).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[1].has(opp_card)).is_false()
	assert_int(state.deck[0]).is_equal(opp_card)


func test_006_kanata_no_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(6, "かなた", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(6, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 6)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(6).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

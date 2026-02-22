extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/065_hiodoshi_ao/card_skills.gd") as GDScript).new()


func test_065_ao_move_to_opp_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(65, "青", ["SEXY"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(65, _load_skill())

	var deck_card: int = H.place_in_deck_top(state, 65)
	var inst_id: int = H.place_on_stage(state, 0, 65)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(65).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[1].has(inst_id)).is_true()
	assert_bool(state.stages[0].has(inst_id)).is_false()
	assert_bool(state.hands[0].has(deck_card)).is_true()


func test_065_ao_opp_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(65, "青", ["SEXY"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(65, _load_skill())

	H.place_on_stage(state, 1, 65)
	H.place_on_stage(state, 1, 65)
	H.place_on_stage(state, 1, 65)
	var inst_id: int = H.place_on_stage(state, 0, 65)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(65).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(inst_id)).is_true()

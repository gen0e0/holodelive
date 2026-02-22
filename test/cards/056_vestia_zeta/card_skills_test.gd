extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/056_vestia_zeta/card_skills.gd") as GDScript).new()


func test_056_zeta_infiltration() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(56, "ゼータ", ["TRICKSTER", "ENJOY"], ["STAFF"], [H.action_skill()]),
		H.make_card_def(99, "OPP_CARD", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(56, _load_skill())

	var opp_hand: int = H.place_in_hand(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 56)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(56).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(inst_id)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_hand, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(56).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"stolen_card": opp_hand}
	result = sr.get_skill(56).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(opp_hand)).is_true()

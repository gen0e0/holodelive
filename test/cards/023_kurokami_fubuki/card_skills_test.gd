extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/023_kurokami_fubuki/card_skills.gd") as GDScript).new()


func test_023_kurokami_self_home_opp_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(23, "黒フブキ", ["TRICKSTER"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(23, _load_skill())

	var opp_card: int = H.place_on_stage(state, 1, 23)
	var inst_id: int = H.place_on_stage(state, 0, 23)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(23).execute_skill(ctx, 0)
	assert_bool(state.home.has(inst_id)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(23).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp_card)).is_true()

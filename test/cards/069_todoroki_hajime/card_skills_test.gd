extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/069_todoroki_hajime/card_skills.gd") as GDScript).new()


func test_069_hajime_both_first_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(69, "はじめ", ["DUELIST"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(69, _load_skill())

	var my_first: int = H.place_on_stage(state, 0, 69)
	var opp_first: int = H.place_on_stage(state, 1, 69)
	var inst_id: int = H.place_on_stage(state, 0, 69)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(69).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(my_first)).is_true()
	assert_bool(state.home.has(opp_first)).is_true()
	assert_bool(state.stages[0].has(inst_id)).is_true()

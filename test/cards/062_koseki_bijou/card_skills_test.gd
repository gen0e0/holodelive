extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/062_koseki_bijou/card_skills.gd") as GDScript).new()


func test_062_bijou_steal_opp_first() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(62, "ビジュー", ["KUSOGAKI", "TRICKSTER"], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(62, _load_skill())

	var opp_first: int = H.place_on_stage(state, 1, 62)
	var inst_id: int = H.place_on_stage(state, 0, 62)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(62).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(opp_first)).is_true()
	assert_bool(state.stages[1].has(opp_first)).is_false()


func test_062_bijou_no_opp_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(62, "ビジュー", ["KUSOGAKI", "TRICKSTER"], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(62, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 62)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(62).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

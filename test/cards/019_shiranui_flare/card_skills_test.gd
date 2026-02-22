extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/019_shiranui_flare/card_skills.gd") as GDScript).new()


func test_019_flare_both_pick() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(19, "フレア", ["INTEL"], ["COOL"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(19, _load_skill())

	var h1: int = H.place_in_home(state, 19)
	var h2: int = H.place_in_home(state, 19)
	var inst_id: int = H.place_on_stage(state, 0, 19)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(19).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, h1, DiffRecorder.new())
	result = sr.get_skill(19).execute_skill(ctx, 0)
	assert_bool(state.hands[0].has(h1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, h2, DiffRecorder.new())
	result = sr.get_skill(19).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(h2)).is_true()


func test_019_flare_home_empty() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(19, "フレア", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(19, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 19)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(19).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/038_harusaki_nodoka/card_skills.gd") as GDScript).new()


func test_038_nodoka_home_to_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(38, "のどか", [], ["ENGLISH"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(38, _load_skill())

	var home_id: int = H.place_in_home(state, 38)
	var inst_id: int = H.place_on_stage(state, 0, 38)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(38).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home_id, DiffRecorder.new())
	result = sr.get_skill(38).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(home_id)).is_true()


func test_038_nodoka_home_empty() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(38, "のどか", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(38, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 38)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(38).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/051_moona_hoshinova/card_skills.gd") as GDScript).new()


func test_051_moona_remove_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(51, "ムーナ", ["VOCAL"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(15, "すいせい", [], [], []),
		H.make_card_def(99, "OTHER", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(51, _load_skill())

	var suisei: int = H.place_on_stage(state, 1, 15)
	var other: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 51)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(51).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(suisei)).is_true()
	assert_bool(state.stages[1].has(other)).is_true()


func test_051_moona_no_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(51, "ムーナ", ["VOCAL"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(99, "OTHER", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(51, _load_skill())

	H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 51)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(51).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.home.size()).is_equal(0)

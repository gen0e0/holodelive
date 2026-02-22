extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/002_minato_aqua/card_skills.gd") as GDScript).new()


func test_002_aqua_home_jp_to_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(2, "あくあ", ["CHARISMA"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(90, "HOT_card", ["ENJOY"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(2, _load_skill())

	var hot_id: int = H.place_in_home(state, 90)
	var inst_id: int = H.place_on_stage(state, 0, 2)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(2).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hot_id, DiffRecorder.new())
	result = sr.get_skill(2).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hot_id)).is_true()
	assert_bool(state.home.has(hot_id)).is_false()


func test_002_aqua_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(2, "あくあ", [], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(90, "card", [], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(2, _load_skill())
	H.place_in_home(state, 90)
	H.place_on_stage(state, 0, 2)
	H.place_on_stage(state, 0, 2)
	var inst_id: int = H.place_on_stage(state, 0, 2)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(2).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

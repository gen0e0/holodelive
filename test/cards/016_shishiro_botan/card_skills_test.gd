extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/016_shishiro_botan/card_skills.gd") as GDScript).new()


func test_016_botan_home_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(16, "ぼたん", ["ENJOY", "OTAKU"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(16, _load_skill())

	var home1: int = H.place_in_home(state, 16)
	var home2: int = H.place_in_home(state, 16)
	var inst_id: int = H.place_on_stage(state, 0, 16)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(16).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home1, DiffRecorder.new())
	result = sr.get_skill(16).execute_skill(ctx, 0)
	assert_bool(state.hands[0].has(home1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, home2, DiffRecorder.new())
	result = sr.get_skill(16).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(home2)).is_true()
	assert_bool(state.home.has(inst_id)).is_true()


func test_016_botan_not_enough_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(16, "ぼたん", ["ENJOY", "OTAKU"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(16, _load_skill())

	H.place_in_home(state, 16)
	var inst_id: int = H.place_on_stage(state, 0, 16)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(16).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

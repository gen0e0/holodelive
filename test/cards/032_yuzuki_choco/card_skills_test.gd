extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/032_yuzuki_choco/card_skills.gd") as GDScript).new()


func test_032_choco_open_opp_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(32, "ちょこ", ["SEXY", "ALCOHOL"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(32, _load_skill())

	var opp_bs: int = H.place_on_backstage(state, 1, 32)
	var inst_id: int = H.place_on_stage(state, 0, 32)

	assert_bool(state.instances[opp_bs].face_down).is_true()

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(32).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.instances[opp_bs].face_down).is_false()


func test_032_choco_no_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(32, "ちょこ", ["SEXY", "ALCOHOL"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(32, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 32)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(32).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/007_kazama_iroha/card_skills.gd") as GDScript).new()


func test_007_iroha_home_jp_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(7, "いろは", ["DUELIST"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(90, "JP_card", ["SEISO"], ["LOVELY"], []),
		H.make_card_def(91, "EN_card", ["SEISO"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(7, _load_skill())

	var jp_id: int = H.place_in_home(state, 90)
	var en_id: int = H.place_in_home(state, 91)
	var inst_id: int = H.place_on_stage(state, 0, 7)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(7).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(jp_id)).is_true()
	assert_bool(result.valid_targets.has(en_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, jp_id, DiffRecorder.new())
	result = sr.get_skill(7).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(jp_id)).is_true()

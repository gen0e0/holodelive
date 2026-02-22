extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	return (load(path) as GDScript).new()


func test_008_koyori_use_opp_play_skill() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(8, "こより", ["INTEL"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(9, "ロボ子", [], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(8, _load_skill("res://cards/008_hakui_koyori/card_skills.gd"))
	sr.register(9, _load_skill("res://cards/009_roboco/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 9)
	var inst_id: int = H.place_on_stage(state, 0, 8)
	H.place_in_deck_top(state, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(8).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new(), sr)
	ctx.data = {}
	result = sr.get_skill(8).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)


func test_008_koyori_no_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(8, "こより", ["INTEL"], ["LOVELY"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(8, _load_skill("res://cards/008_hakui_koyori/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 8)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(8).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

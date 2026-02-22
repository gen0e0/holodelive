extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/053_anya_melfissa/card_skills.gd") as GDScript).new()


func test_053_anya_play_hot() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(53, "アーニャ", ["DUELIST"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(99, "HOT_CARD", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(53, _load_skill())

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 53)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hand_card)).is_true()


func test_053_anya_play_indonesia() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(53, "アーニャ", ["DUELIST"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(99, "ID_CARD", [], ["INDONESIA"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(53, _load_skill())

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 53)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "backstage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.backstages[0]).is_equal(hand_card)

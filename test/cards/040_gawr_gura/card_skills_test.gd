extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/040_gawr_gura/card_skills.gd") as GDScript).new()


func test_040_gura_play_en() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(40, "ぐら", ["CHARISMA"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(99, "EN_CARD", [], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(40, _load_skill())

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 40)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(40).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	result = sr.get_skill(40).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hand_card)).is_true()


func test_040_gura_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(40, "ぐら", ["CHARISMA"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(99, "EN_CARD", [], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(40, _load_skill())

	H.place_in_hand(state, 0, 99)
	H.place_on_stage(state, 0, 40)
	H.place_on_stage(state, 0, 40)
	var inst_id: int = H.place_on_stage(state, 0, 40)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(40).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

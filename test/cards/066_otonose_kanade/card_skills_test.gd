extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/066_otonose_kanade/card_skills.gd") as GDScript).new()


func test_066_kanade_use_prev_skill() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(66, "奏", ["KUSOGAKI"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(9, "ロボ子", [], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(66, _load_skill())
	sr.register(9, (load("res://cards/009_roboco/card_skills.gd") as GDScript).new())

	var prev_card: int = H.place_on_stage(state, 0, 9)
	var inst_id: int = H.place_on_stage(state, 0, 66)
	H.place_in_deck_top(state, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(66).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)


func test_066_kanade_first_position_no_prev() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(66, "奏", ["KUSOGAKI"], ["LOVELY"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(66, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 66)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(66).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/011_momosuzu_nene/card_skills.gd") as GDScript).new()


func test_011_nene_return_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(11, "ねね", ["KUSOGAKI"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(11, _load_skill())

	var other_card: int = H.place_on_stage(state, 0, 11)
	var inst_id: int = H.place_on_stage(state, 0, 11)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(11).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(other_card)).is_true()
	assert_bool(result.valid_targets.has(inst_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, other_card, DiffRecorder.new())
	result = sr.get_skill(11).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(other_card)).is_true()


func test_011_nene_no_other_cards() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(11, "ねね", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(11, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 11)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(11).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

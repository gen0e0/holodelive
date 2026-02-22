extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/031_takane_lui/card_skills.gd") as GDScript).new()


func test_031_lui_en_id_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(31, "ルイ", ["INTEL"], ["HOT"], [H.play_skill()]),
		H.make_card_def(90, "EN_card", ["VOCAL"], ["ENGLISH"], []),
		H.make_card_def(91, "JP_card", ["VOCAL"], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(31, _load_skill())

	var en_id: int = H.place_in_home(state, 90)
	var jp_id: int = H.place_in_home(state, 91)
	var inst_id: int = H.place_on_stage(state, 0, 31)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(31).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(en_id)).is_true()
	assert_bool(result.valid_targets.has(jp_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, en_id, DiffRecorder.new())
	result = sr.get_skill(31).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(en_id)).is_true()

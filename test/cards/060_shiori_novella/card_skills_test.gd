extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/060_shiori_novella/card_skills.gd") as GDScript).new()


func test_060_shiori_intel_from_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(60, "シオリ", ["INTEL"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(90, "INTEL_card", ["INTEL"], ["COOL"], []),
		H.make_card_def(91, "OTHER_card", ["VOCAL"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(60, _load_skill())

	var intel_home: int = H.place_in_home(state, 90)
	var other_home: int = H.place_in_home(state, 91)
	var inst_id: int = H.place_on_stage(state, 0, 60)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(60).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(intel_home)).is_true()
	assert_bool(result.valid_targets.has(other_home)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, intel_home, DiffRecorder.new())
	result = sr.get_skill(60).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(intel_home)).is_true()


func test_060_shiori_intel_from_opp_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(60, "シオリ", ["INTEL"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(90, "INTEL_card", ["INTEL"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(60, _load_skill())

	var opp_intel: int = H.place_on_stage(state, 1, 90)
	var inst_id: int = H.place_on_stage(state, 0, 60)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(60).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(opp_intel)).is_true()

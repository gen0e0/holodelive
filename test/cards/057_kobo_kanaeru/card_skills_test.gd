extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/057_kobo_kanaeru/card_skills.gd") as GDScript).new()


func test_057_kobo_return_by_kusogaki_count() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(57, "こぼ", ["KUSOGAKI", "CHARISMA"], ["STAFF"], [H.play_skill()]),
		H.make_card_def(99, "KUSO", ["KUSOGAKI"], ["HOT"], []),
		H.make_card_def(98, "OPP", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(57, _load_skill())

	var opp1: int = H.place_on_stage(state, 1, 98)
	var opp2: int = H.place_on_stage(state, 1, 98)
	var kuso_card: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 57)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	ctx.data = {"remaining": 2}
	result = sr.get_skill(57).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp2, DiffRecorder.new())
	ctx.data = {"remaining": 1}
	result = sr.get_skill(57).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp2)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


func test_057_kobo_no_kusogaki() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(57, "こぼ_no_kuso", [], ["STAFF"], [H.play_skill()]),
		H.make_card_def(98, "OPP", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(57, _load_skill())

	H.place_on_stage(state, 1, 98)
	var inst_id: int = H.place_on_stage(state, 0, 57)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

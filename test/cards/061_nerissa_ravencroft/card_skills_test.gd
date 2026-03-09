extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/061_nerissa_ravencroft/card_skills.gd") as GDScript).new()


func test_061_nerissa_send_sexy_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(61, "ネリッサ", ["VOCAL", "SEXY"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(90, "SEXY_card", ["SEXY"], ["HOT"], []),
		H.make_card_def(91, "SEISO_card", ["SEISO"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(61, _load_skill())

	var sexy_id: int = H.place_on_stage(state, 1, 90)
	var seiso_id: int = H.place_on_stage(state, 1, 91)
	var inst_id: int = H.place_on_stage(state, 0, 61)

	# Phase 0: SEXYのみ選択可能
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(61).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(sexy_id)).is_true()
	assert_bool(result.valid_targets.has(seiso_id)).is_false()

	# Phase 1: 選択したSEXYが帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, sexy_id, DiffRecorder.new())
	result = sr.get_skill(61).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(sexy_id)).is_true()


func test_061_nerissa_no_sexy_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(61, "ネリッサ", ["VOCAL", "SEXY"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(91, "SEISO_card", ["SEISO"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(61, _load_skill())

	H.place_on_stage(state, 1, 91)
	var inst_id: int = H.place_on_stage(state, 0, 61)

	# SEXY対象なし → 即完了
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(61).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

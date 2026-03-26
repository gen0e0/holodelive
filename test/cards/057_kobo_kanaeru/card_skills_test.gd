extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/057_kobo_kanaeru/card_skills.gd") as GDScript).new()


func test_057_kobo_multi_select_home() -> void:
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

	# Phase 0: KUSOGAKI 2枚 → select_max=2 の一括選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	var choice: Dictionary = result.choices[0]
	assert_int(choice["select_max"]).is_equal(2)
	assert_int(choice["select_min"]).is_equal(2)

	# Phase 1: 2枚同時選択 → 両方帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, [opp1, opp2], DiffRecorder.new())
	result = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp1)).is_true()
	assert_bool(state.home.has(opp2)).is_true()
	assert_bool(not state.stages[1].has(opp1)).is_true()
	assert_bool(not state.stages[1].has(opp2)).is_true()


func test_057_kobo_kusogaki_exceeds_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(57, "こぼ", ["KUSOGAKI", "CHARISMA"], ["STAFF"], [H.play_skill()]),
		H.make_card_def(99, "KUSO", ["KUSOGAKI"], ["HOT"], []),
		H.make_card_def(98, "OPP", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(57, _load_skill())

	# 相手のフィールドに1枚、KUSOGAKIは2枚 → select_max=1（min(2,1)）
	var opp1: int = H.place_on_stage(state, 1, 98)
	H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 57)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	var choice: Dictionary = result.choices[0]
	assert_int(choice["select_max"]).is_equal(1)

	# 1枚選択 → 帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	result = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp1)).is_true()


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


func test_057_kobo_skips_face_down() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(57, "こぼ", ["KUSOGAKI"], ["STAFF"], [H.play_skill()]),
		H.make_card_def(98, "OPP", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(57, _load_skill())

	# 相手フィールドに face_down のカードのみ → ターゲットなし → DONE
	var opp1: int = H.place_on_stage(state, 1, 98)
	state.instances[opp1].face_down = true
	var inst_id: int = H.place_on_stage(state, 0, 57)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

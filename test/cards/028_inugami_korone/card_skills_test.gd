extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/028_inugami_korone/card_skills.gd") as GDScript).new()


func test_028_korone_return_two() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(28, "ころね", ["ENJOY"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(28, _load_skill())

	var opp1: int = H.place_on_stage(state, 1, 28)
	var opp2: int = H.place_on_stage(state, 1, 28)
	var inst_id: int = H.place_on_stage(state, 0, 28)

	# Phase 0: 選択待ち（1〜2枚）
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(28).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(result.select_min).is_equal(1)
	assert_int(result.select_max).is_equal(2)

	# Phase 1: 2枚選択 → 両方手札に戻る
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, [opp1, opp2], DiffRecorder.new())
	result = sr.get_skill(28).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(opp1)).is_true()
	assert_bool(state.hands[1].has(opp2)).is_true()


func test_028_korone_return_one_when_only_one_target() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(28, "ころね", ["ENJOY"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(28, _load_skill())

	var opp1: int = H.place_on_stage(state, 1, 28)
	var inst_id: int = H.place_on_stage(state, 0, 28)

	# Phase 0: 対象1枚 → select_max=1
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(28).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(result.select_max).is_equal(1)

	# Phase 1: 1枚選択（単一値）
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	result = sr.get_skill(28).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(opp1)).is_true()


func test_028_korone_no_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(28, "ころね", ["ENJOY"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(28, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 28)

	# 対象なし → 即完了
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(28).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

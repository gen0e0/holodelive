extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/033_aki_rosenthal/card_skills.gd") as GDScript).new()


func test_033_aki_guest_own_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(33, "アキ", ["ALCOHOL", "DUELIST"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(33, _load_skill())

	# 楽屋に表向きカードを配置（オープン済み状態）
	var my_bs: int = H.place_on_backstage(state, 0, 33)
	state.instances[my_bs].face_down = false
	var inst_id: int = H.place_on_stage(state, 0, 33)

	assert_bool(state.instances[my_bs].face_down).is_false()

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(33).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# 表向き → 裏向き（ゲスト化）
	assert_bool(state.instances[my_bs].face_down).is_true()


func test_033_aki_skip_already_guest() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(33, "アキ", ["ALCOHOL", "DUELIST"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(33, _load_skill())

	# 楽屋に裏向きカード（既にゲスト状態）
	var my_bs: int = H.place_on_backstage(state, 0, 33)
	var inst_id: int = H.place_on_stage(state, 0, 33)

	assert_bool(state.instances[my_bs].face_down).is_true()

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(33).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# 既にゲストなので変化なし
	assert_bool(state.instances[my_bs].face_down).is_true()

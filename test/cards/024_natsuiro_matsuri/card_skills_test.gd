extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/024_natsuiro_matsuri/card_skills.gd") as GDScript).new()


func test_024_matsuri_seiso_home_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(24, "まつり", ["SEISO"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "SEISO_CARD", ["SEISO"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(24, _load_skill())

	var seiso_card: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 24)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(24).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(seiso_card)).is_true()
	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("WILD")


func test_024_matsuri_no_seiso_no_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(24, "まつり", ["SEISO"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "NOT_SEISO", ["OTAKU"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(24, _load_skill())

	H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 24)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(24).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.instances[inst_id].modifiers.size()).is_equal(0)


func test_024_matsuri_self_not_removed() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(24, "まつり", ["SEISO"], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(24, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 24)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(24).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(inst_id)).is_true()

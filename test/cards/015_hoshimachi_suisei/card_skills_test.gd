extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/015_hoshimachi_suisei/card_skills.gd") as GDScript).new()


func test_015_suisei_adjacent_vocal() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(15, "すいせい", ["VOCAL"], ["COOL"], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(15, _load_skill())

	var left: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 15)
	var right: int = H.place_on_stage(state, 0, 99)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(15).execute_skill(ctx, 0)

	assert_int(state.instances[left].modifiers.size()).is_equal(1)
	assert_str(state.instances[left].modifiers[0].value).is_equal("VOCAL")
	assert_int(state.instances[right].modifiers.size()).is_equal(1)
	assert_str(state.instances[right].modifiers[0].value).is_equal("VOCAL")
	assert_int(state.instances[inst_id].modifiers.size()).is_equal(0)


func test_015_suisei_edge_position() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(15, "すいせい", ["VOCAL"], ["COOL"], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(15, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 15)
	var right: int = H.place_on_stage(state, 0, 99)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(15).execute_skill(ctx, 0)

	assert_int(state.instances[right].modifiers.size()).is_equal(1)
	assert_str(state.instances[right].modifiers[0].value).is_equal("VOCAL")

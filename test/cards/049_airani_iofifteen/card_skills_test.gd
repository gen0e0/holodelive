extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/049_airani_iofifteen/card_skills.gd") as GDScript).new()


func test_049_iofi_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(49, "アイラニ", ["SEISO"], ["INDONESIA"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(49, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 49)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(49).execute_skill(ctx, 0)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("WILD")


func test_049_erofi_matsuri_immune() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(49, "アイラニ", ["SEISO"], ["INDONESIA"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(49, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 49)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(49).execute_skill(ctx, 1)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("MATSURI_IMMUNE")

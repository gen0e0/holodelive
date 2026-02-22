extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/001_tokino_sora/card_skills.gd") as GDScript).new()


func test_001_sora_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(1, "そら", ["SEISO"], ["LOVELY"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(1, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 1)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(1).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("WILD")


func test_001_sora_rank_up() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(1, "そら", ["SEISO"], ["LOVELY"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(1, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 1)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(1).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("RANK_UP")

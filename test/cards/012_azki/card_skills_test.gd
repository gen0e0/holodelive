extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/012_azki/card_skills.gd") as GDScript).new()


func test_012_azki_diva_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(12, "AZKi", ["SEISO"], ["COOL"], [H.passive_skill(), H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(12, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 12)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(12).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("WILD")


func test_012_azki_guess_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(12, "AZKi", ["SEISO"], ["COOL"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "SEISO_CARD", ["SEISO"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(12, _load_skill())

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 12)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hand_card)).is_true()


func test_012_azki_guess_no_seiso() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(12, "AZKi", ["SEISO"], ["COOL"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "NOT_SEISO", ["OTAKU"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(12, _load_skill())

	H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 12)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

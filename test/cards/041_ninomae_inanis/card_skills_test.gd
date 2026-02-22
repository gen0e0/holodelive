extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/041_ninomae_inanis/card_skills.gd") as GDScript).new()


func test_041_ina_adjacent_english() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill())

	var left: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 0)

	assert_int(state.instances[left].modifiers.size()).is_equal(1)
	assert_int(state.instances[left].modifiers[0].type).is_equal(Enums.ModifierType.SUIT_ADD)
	assert_str(state.instances[left].modifiers[0].value).is_equal("ENGLISH")


func test_041_ina_dice_roll_1_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 1)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 1, DiffRecorder.new())
	ctx.data = {}
	var result: SkillResult = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(inst_id)).is_true()


func test_041_ina_dice_roll_2_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 1)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 2, DiffRecorder.new())
	ctx.data = {}
	var result: SkillResult = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(inst_id)).is_true()


func test_041_ina_dice_roll_6_choose_opp() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "OPP", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill())

	var opp_card: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 1)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 6, DiffRecorder.new())
	ctx.data = {}
	var result: SkillResult = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp_card, DiffRecorder.new())
	ctx.data = {"roll": 6}
	result = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp_card)).is_true()

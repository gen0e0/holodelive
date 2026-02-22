extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/063_fuwawa_abyssgard/card_skills.gd") as GDScript).new()


func test_063_fuwawa_find_mococo_in_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill())

	var mococo: int = H.place_in_deck_top(state, 64)
	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(mococo)).is_true()


func test_063_fuwawa_find_mococo_in_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill())

	var mococo: int = H.place_in_home(state, 64)
	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(mococo)).is_true()


func test_063_fuwawa_find_mococo_in_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill())

	var mococo: int = H.place_in_hand(state, 0, 64)
	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(mococo)).is_true()
	assert_bool(state.hands[0].has(mococo)).is_false()


func test_063_fuwawa_not_found() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


func test_063_fuwawa_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill())

	H.place_in_deck_top(state, 64)
	H.place_on_stage(state, 0, 63)
	H.place_on_stage(state, 0, 63)
	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck.size()).is_equal(1)

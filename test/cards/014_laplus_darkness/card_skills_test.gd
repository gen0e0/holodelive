extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/014_laplus_darkness/card_skills.gd") as GDScript).new()


func test_014_laplus_find_holox() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(14, "ラプラス", ["OTAKU", "KUSOGAKI"], ["COOL"], [H.play_skill()]),
		H.make_card_def(31, "ルイ", ["CHARISMA"], ["COOL"], []),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(14, _load_skill())

	var other1: int = H.place_in_deck_top(state, 99)
	var lui: int = H.place_in_deck_top(state, 31)
	var inst_id: int = H.place_on_stage(state, 0, 14)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(14).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(lui)).is_true()


func test_014_laplus_not_found_all_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(14, "ラプラス", ["OTAKU", "KUSOGAKI"], ["COOL"], [H.play_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(14, _load_skill())

	var c1: int = H.place_in_deck_top(state, 99)
	var c2: int = H.place_in_deck_top(state, 99)
	var inst_id: int = H.place_on_stage(state, 0, 14)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(14).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(c1)).is_true()
	assert_bool(state.home.has(c2)).is_true()
	assert_int(state.deck.size()).is_equal(0)


func test_014_laplus_skip_non_holox_before_hit() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(14, "ラプラス", ["OTAKU", "KUSOGAKI"], ["COOL"], [H.play_skill()]),
		H.make_card_def(7, "いろは", ["REACTION"], ["COOL"], []),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(14, _load_skill())

	var iroha: int = H.place_in_deck_top(state, 7)
	var other: int = H.place_in_deck_top(state, 99)
	var inst_id: int = H.place_on_stage(state, 0, 14)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(14).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(other)).is_true()
	assert_bool(state.stages[0].has(iroha)).is_true()

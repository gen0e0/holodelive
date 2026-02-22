extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/067_ichijou_ririka/card_skills.gd") as GDScript).new()


func test_067_ririka_find_alcohol() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(67, "莉々華", ["TRICKSTER", "ALCOHOL"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "NO_ALCOHOL", ["OTAKU"], ["HOT"], []),
		H.make_card_def(98, "HAS_ALCOHOL", ["ALCOHOL"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(67, _load_skill())

	var alcohol_card: int = H.place_in_deck_top(state, 98)
	var no1: int = H.place_in_deck_top(state, 99)
	var no2: int = H.place_in_deck_top(state, 99)
	var inst_id: int = H.place_on_stage(state, 0, 67)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(67).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(state.home.has(no2)).is_true()
	assert_bool(state.home.has(no1)).is_true()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, "stage", DiffRecorder.new())
	ctx.data = {"found_card": alcohol_card}
	result = sr.get_skill(67).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(alcohol_card)).is_true()


func test_067_ririka_no_alcohol() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(67, "莉々華", ["TRICKSTER", "ALCOHOL"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "NO_ALCOHOL", ["OTAKU"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(67, _load_skill())

	var c1: int = H.place_in_deck_top(state, 99)
	var c2: int = H.place_in_deck_top(state, 99)
	var c3: int = H.place_in_deck_top(state, 99)
	var inst_id: int = H.place_on_stage(state, 0, 67)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(67).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(c1)).is_true()
	assert_bool(state.home.has(c2)).is_true()
	assert_bool(state.home.has(c3)).is_true()

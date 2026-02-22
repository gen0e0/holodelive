extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/050_kureiji_ollie/card_skills.gd") as GDScript).new()


func test_050_ollie_bottom_draw() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(50, "オリー", ["OTAKU", "INTEL"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(50, _load_skill())

	var top_id: int = H.place_in_deck_top(state, 50)
	var bottom_id: int = H.place_in_deck_bottom(state, 50)
	var inst_id: int = H.place_on_stage(state, 0, 50)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(50).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(bottom_id)).is_true()
	assert_int(state.deck.size()).is_equal(1)
	assert_int(state.deck[0]).is_equal(top_id)


func test_050_ollie_empty_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(50, "オリー", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(50, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 50)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(50).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(0)

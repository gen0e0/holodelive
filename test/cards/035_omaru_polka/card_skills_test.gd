extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/035_omaru_polka/card_skills.gd") as GDScript).new()


func test_035_polka_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(35, "ポルカ", ["TRICKSTER"], ["HOT"], [H.play_skill(), H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(35, _load_skill())

	H.place_in_deck_top(state, 35)
	var hand_card: int = H.place_in_hand(state, 0, 35)
	var inst_id: int = H.place_on_stage(state, 0, 35)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(35).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(state.hands[0].size()).is_equal(2)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	result = sr.get_skill(35).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck[0]).is_equal(hand_card)


func test_035_polka_action_swap() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(35, "ポルカ", ["TRICKSTER"], ["HOT"], [H.play_skill(), H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(35, _load_skill())

	var bottom_card: int = H.place_in_deck_bottom(state, 35)
	var inst_id: int = H.place_on_stage(state, 0, 35)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(35).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(bottom_card)).is_true()
	assert_int(state.deck.back()).is_equal(inst_id)

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/048_nanashi_mumei/card_skills.gd") as GDScript).new()


func test_048_mumei_swap_bottom() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(48, "ムメイ", ["TRICKSTER"], ["INDONESIA"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(48, _load_skill())

	var hand_card: int = H.place_in_hand(state, 0, 48)
	var deck_card: int = H.place_in_deck_top(state, 48)
	var inst_id: int = H.place_on_stage(state, 0, 48)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(48).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	result = sr.get_skill(48).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck.back()).is_equal(hand_card)
	assert_bool(state.hands[0].has(deck_card)).is_true()

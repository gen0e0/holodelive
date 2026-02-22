extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/018_sakamata_chloe/card_skills.gd") as GDScript).new()


func test_018_chloe_reset() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(18, "クロヱ", ["DUELIST", "SEXY"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(18, _load_skill())

	var h1: int = H.place_in_hand(state, 0, 18)
	var h2: int = H.place_in_hand(state, 0, 18)
	for i in range(5):
		H.place_in_deck_top(state, 18)
	var inst_id: int = H.place_on_stage(state, 0, 18)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(18).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(3)
	assert_bool(state.home.has(h1)).is_true()
	assert_bool(state.home.has(h2)).is_true()
	assert_int(state.deck.size()).is_equal(2)

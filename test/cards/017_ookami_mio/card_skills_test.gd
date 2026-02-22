extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/017_ookami_mio/card_skills.gd") as GDScript).new()


func test_017_mio_discard_all_draw_two() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(17, "ミオ", ["REACTION", "INTEL"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(17, _load_skill())

	var opp1: int = H.place_in_hand(state, 1, 17)
	var opp2: int = H.place_in_hand(state, 1, 17)
	for i in range(3):
		H.place_in_deck_top(state, 17)
	var inst_id: int = H.place_on_stage(state, 0, 17)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(17).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp1)).is_true()
	assert_bool(state.home.has(opp2)).is_true()
	assert_int(state.hands[1].size()).is_equal(2)
	assert_int(state.deck.size()).is_equal(1)

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/043_watson_amelia/card_skills.gd") as GDScript).new()


func test_043_amelia_hand_swap() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(43, "アメリア", ["ENJOY", "TRICKSTER"], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(43, _load_skill())

	var my1: int = H.place_in_hand(state, 0, 43)
	var my2: int = H.place_in_hand(state, 0, 43)
	var opp1: int = H.place_in_hand(state, 1, 43)
	var inst_id: int = H.place_on_stage(state, 0, 43)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(43).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)
	assert_bool(state.hands[0].has(opp1)).is_true()
	assert_int(state.hands[1].size()).is_equal(2)
	assert_bool(state.hands[1].has(my1)).is_true()
	assert_bool(state.hands[1].has(my2)).is_true()

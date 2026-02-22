extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/025_usada_pekora/card_skills.gd") as GDScript).new()


func test_025_pekora_swap_and_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(25, "ぺこら", ["CHARISMA"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(25, _load_skill())

	var deck_top: int = H.place_in_deck_top(state, 25)
	var hand_card: int = H.place_in_hand(state, 0, 25)
	var inst_id: int = H.place_on_stage(state, 0, 25)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(25).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(25).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(state.hands[0].has(deck_top)).is_true()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"drawn_card": deck_top}
	result = sr.get_skill(25).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(deck_top)).is_true()

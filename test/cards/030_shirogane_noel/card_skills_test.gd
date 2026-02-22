extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/030_shirogane_noel/card_skills.gd") as GDScript).new()


func test_030_noel_draw_and_return() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(30, "ノエル", ["DUELIST"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(30, _load_skill())

	for i in range(4):
		H.place_in_deck_top(state, 30)
	var inst_id: int = H.place_on_stage(state, 0, 30)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(state.hands[0].size()).is_equal(2)
	assert_int(state.deck.size()).is_equal(2)

	var h0: int = state.hands[0][0]
	var h1: int = state.hands[0][1]

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, h0, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, h1, DiffRecorder.new())
	result = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(0)
	assert_int(state.deck.size()).is_equal(4)
	assert_int(state.deck[0]).is_equal(h1)

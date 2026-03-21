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

	# phase 0: ドロー2枚 + SELECT_CARD 待ち（2枚選択、ui_hint = "deck_return"）
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(result.select_min).is_equal(2)
	assert_int(result.select_max).is_equal(2)
	assert_str(result.ui_hint).is_equal("deck_return")
	assert_int(state.hands[0].size()).is_equal(2)
	assert_int(state.deck.size()).is_equal(2)

	var h0: int = state.hands[0][0]
	var h1: int = state.hands[0][1]

	# phase 1: [h0, h1] を返す → h0 がデッキトップ、h1 が2番目
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, [h0, h1], DiffRecorder.new())
	result = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(0)
	assert_int(state.deck.size()).is_equal(4)
	assert_int(state.deck[0]).is_equal(h0)
	assert_int(state.deck[1]).is_equal(h1)


func test_030_noel_reverse_order() -> void:
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
	sr.get_skill(30).execute_skill(ctx, 0)

	var h0: int = state.hands[0][0]
	var h1: int = state.hands[0][1]

	# 逆順: [h1, h0] → h1 がデッキトップ、h0 が2番目
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, [h1, h0], DiffRecorder.new())
	var result: SkillResult = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck[0]).is_equal(h1)
	assert_int(state.deck[1]).is_equal(h0)

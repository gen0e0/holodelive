extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/068_juufuutei_raden/card_skills.gd") as GDScript).new()


func test_068_raden_reorder_3_cards() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(68, "らでん", ["OTAKU"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(68, _load_skill())

	var c1: int = H.place_in_deck_top(state, 68)
	var c2: int = H.place_in_deck_top(state, 68)
	var c3: int = H.place_in_deck_top(state, 68)
	# デッキ先頭: c3, c2, c1
	var inst_id: int = H.place_on_stage(state, 0, 68)

	# Phase 0: 3枚を見る → select_min=3, select_max=3
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	var choice: Dictionary = result.choices[0]
	assert_int(choice["select_min"]).is_equal(3)
	assert_int(choice["select_max"]).is_equal(3)

	# Phase 1: 並べ替え c1, c3, c2 → デッキトップから c1, c3, c2
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, [c1, c3, c2], DiffRecorder.new())
	ctx.data = {"top_cards": [c3, c2, c1]}
	result = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck[0]).is_equal(c1)
	assert_int(state.deck[1]).is_equal(c3)
	assert_int(state.deck[2]).is_equal(c2)


func test_068_raden_reorder_2_cards() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(68, "らでん", ["OTAKU"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(68, _load_skill())

	var c1: int = H.place_in_deck_top(state, 68)
	var c2: int = H.place_in_deck_top(state, 68)
	# デッキ先頭: c2, c1 (2枚のみ)
	var inst_id: int = H.place_on_stage(state, 0, 68)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	var choice: Dictionary = result.choices[0]
	assert_int(choice["select_min"]).is_equal(2)
	assert_int(choice["select_max"]).is_equal(2)

	# 逆順に並べ替え
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, [c1, c2], DiffRecorder.new())
	ctx.data = {"top_cards": [c2, c1]}
	result = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck[0]).is_equal(c1)
	assert_int(state.deck[1]).is_equal(c2)


func test_068_raden_deck_too_small() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(68, "らでん", ["OTAKU"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(68, _load_skill())

	# デッキ1枚以下 → スキル不発
	H.place_in_deck_top(state, 68)
	var inst_id: int = H.place_on_stage(state, 0, 68)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

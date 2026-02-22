extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/009_roboco/card_skills.gd") as GDScript).new()


func test_009_roboco_draw_one() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(9, "ロボ子さん", ["SEXY"], ["LOVELY"], [H.play_skill("こーせーのー")])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(9, _load_skill())

	H.place_in_deck_top(state, 9)
	H.place_in_deck_top(state, 9)
	H.place_in_deck_top(state, 9)
	var inst_id: int = H.place_on_stage(state, 0, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var skill: BaseCardSkill = sr.get_skill(9)
	var result: SkillResult = skill.execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)
	assert_int(state.deck.size()).is_equal(2)


func test_009_roboco_empty_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(9, "ロボ子さん", ["SEXY"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(9, _load_skill())
	var inst_id: int = H.place_on_stage(state, 0, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var skill: BaseCardSkill = sr.get_skill(9)
	var result: SkillResult = skill.execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(0)

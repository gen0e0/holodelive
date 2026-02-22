extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/044_takanashi_kiara/card_skills.gd") as GDScript).new()


func test_044_kiara_use_home_play_skill() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(44, "キアラ", ["REACTION"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(9, "ロボ子", [], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(44, _load_skill())
	sr.register(9, (load("res://cards/009_roboco/card_skills.gd") as GDScript).new())

	var home_card: int = H.place_in_home(state, 9)
	var inst_id: int = H.place_on_stage(state, 0, 44)
	H.place_in_deck_top(state, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(44).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home_card, DiffRecorder.new(), sr)
	ctx.data = {}
	result = sr.get_skill(44).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)

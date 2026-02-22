extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/052_ayunda_risu/card_skills.gd") as GDScript).new()


func test_052_risu_split() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(52, "リス", ["ENJOY"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(52, _load_skill())

	var top1: int = H.place_in_deck_top(state, 52)
	var top2: int = H.place_in_deck_top(state, 52)
	var inst_id: int = H.place_on_stage(state, 0, 52)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(52).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, top2, DiffRecorder.new())
	ctx.data = {"card1": top2, "card2": top1}
	result = sr.get_skill(52).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(top2)).is_true()
	assert_bool(state.hands[1].has(top1)).is_true()

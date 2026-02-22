extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/058_kiryu_coco/card_skills.gd") as GDScript).new()


func test_058_coco_all_home_self_removed() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(58, "ココ", [], [], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(58, _load_skill())

	var my_other: int = H.place_on_stage(state, 0, 99)
	var opp_card: int = H.place_on_stage(state, 1, 99)
	var opp_bs: int = H.place_on_backstage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 58)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(58).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(my_other)).is_true()
	assert_bool(state.home.has(opp_card)).is_true()
	assert_bool(state.home.has(opp_bs)).is_true()
	assert_bool(state.removed.has(inst_id)).is_true()
	assert_bool(state.stages[0].has(inst_id)).is_false()

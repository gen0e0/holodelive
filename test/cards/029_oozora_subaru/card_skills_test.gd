extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/029_oozora_subaru/card_skills.gd") as GDScript).new()


func test_029_subaru_police() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(29, "スバル", ["REACTION"], ["HOT"], [H.play_skill()]),
		H.make_card_def(90, "SEXY_card", ["SEXY"], ["HOT"], []),
		H.make_card_def(91, "SEISO_card", ["SEISO"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(29, _load_skill())

	var sexy_id: int = H.place_on_stage(state, 1, 90)
	var seiso_id: int = H.place_on_stage(state, 1, 91)
	var inst_id: int = H.place_on_stage(state, 0, 29)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(29).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(sexy_id)).is_true()
	assert_bool(result.valid_targets.has(seiso_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, sexy_id, DiffRecorder.new())
	result = sr.get_skill(29).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(sexy_id)).is_true()

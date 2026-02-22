extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/064_mococo_abyssgard/card_skills.gd") as GDScript).new()


func test_064_mococo_find_fuwawa_in_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(64, _load_skill())

	var fuwawa: int = H.place_in_deck_top(state, 63)
	var inst_id: int = H.place_on_stage(state, 0, 64)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(64).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(fuwawa)).is_true()


func test_064_mococo_not_found() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(64, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 64)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(64).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

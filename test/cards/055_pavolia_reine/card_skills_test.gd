extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/055_pavolia_reine/card_skills.gd") as GDScript).new()


func test_055_reine_adjacent_indonesia() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(55, "レイネ", ["SEXY"], ["STAFF"], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(55, _load_skill())

	var left: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 55)
	var right: int = H.place_on_stage(state, 0, 99)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(55).execute_skill(ctx, 0)

	assert_str(state.instances[left].modifiers[0].value).is_equal("INDONESIA")
	assert_str(state.instances[right].modifiers[0].value).is_equal("INDONESIA")

extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/004_nakiri_ayame/card_skills.gd") as GDScript).new()


func test_004_ayame_first_ready() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(4, "あやめ", ["VOCAL", "DUELIST"], ["LOVELY"], [H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(4, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 4)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(4).execute_skill(ctx, 0)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("FIRST_READY")

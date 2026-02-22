extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/005_sakura_miko/card_skills.gd") as GDScript).new()


func test_005_miko_double_win() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(5, "みこ", ["ENJOY"], ["LOVELY"], [H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(5, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 5)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(5).execute_skill(ctx, 0)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("DOUBLE_WIN")

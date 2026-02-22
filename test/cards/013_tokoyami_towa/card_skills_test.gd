extends GdUnitTestSuite

var H := SkillTestHelper


func _load_skill() -> BaseCardSkill:
	return (load("res://cards/013_tokoyami_towa/card_skills.gd") as GDScript).new()


func test_013_towa_protection() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(13, "トワ", ["CHARISMA"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(13, _load_skill())

	var inst_id: int = H.place_on_stage(state, 0, 13)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(13).execute_skill(ctx, 0)
	assert_int(state.turn_flags.get("protection", -1)).is_equal(0)

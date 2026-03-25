extends GdUnitTestSuite

## 同時選択（Simultaneous Choice）のテスト。

var H := SkillTestHelper


## テスト用: 両プレイヤーに同時選択を要求し、結果を data に保存
class SimultaneousTestSkill extends BaseCardSkill:
	func _skill_0(ctx: SkillContext) -> SkillResult:
		if ctx.phase == 0:
			return SkillResult.waiting_choices([
				{
					"target_player": ctx.player,
					"choice_type": Enums.ChoiceType.SELECT_CARD,
					"valid_targets": [100, 200, 300],
				},
				{
					"target_player": 1 - ctx.player,
					"choice_type": Enums.ChoiceType.SELECT_CARD,
					"valid_targets": [400, 500, 600],
				},
			])
		else:
			ctx.data["p0_choice"] = ctx.choice_results[0]
			ctx.data["p1_choice"] = ctx.choice_results[1]
			return SkillResult.done()


## テスト用: 単一選択（後方互換確認）
class SingleTestSkill extends BaseCardSkill:
	func _skill_0(ctx: SkillContext) -> SkillResult:
		if ctx.phase == 0:
			return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, [10, 20])
		else:
			ctx.data["result"] = ctx.choice_result
			ctx.data["results_count"] = ctx.choice_results.size()
			return SkillResult.done()


func test_waiting_choices_creates_multiple_pending() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(99, "テスト", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(99, SimultaneousTestSkill.new())
	var inst_id: int = H.place_on_stage(state, 0, 99)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(99).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(result.choices.size()).is_equal(2)
	assert_int(result.choices[0]["target_player"]).is_equal(0)
	assert_int(result.choices[1]["target_player"]).is_equal(1)


func test_game_controller_creates_two_pending_choices() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(99, "テスト", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(99, SimultaneousTestSkill.new())
	var inst_id: int = H.place_on_stage(state, 0, 99)

	var gc := GameController.new(state, env.registry, sr)
	gc._push_skill(99, 0, inst_id, 0)
	gc._resolve_skill_stack()

	assert_int(state.pending_choices.size()).is_equal(2)
	assert_int(state.pending_choices[0].target_player).is_equal(0)
	assert_int(state.pending_choices[1].target_player).is_equal(1)
	assert_bool(state.pending_choices[0].resolved).is_false()
	assert_bool(state.pending_choices[1].resolved).is_false()


func test_partial_resolve_does_not_resume_skill() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(99, "テスト", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(99, SimultaneousTestSkill.new())
	var inst_id: int = H.place_on_stage(state, 0, 99)

	var gc := GameController.new(state, env.registry, sr)
	gc._push_skill(99, 0, inst_id, 0)
	gc._resolve_skill_stack()

	# P0 だけ resolve
	gc.submit_choice(0, 200)

	# まだ waiting（P1 未解決）
	assert_bool(gc.is_waiting_for_choice()).is_true()
	assert_bool(state.pending_choices[0].resolved).is_true()
	assert_bool(state.pending_choices[1].resolved).is_false()


func test_full_resolve_resumes_skill() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(99, "テスト", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(99, SimultaneousTestSkill.new())
	var inst_id: int = H.place_on_stage(state, 0, 99)

	var gc := GameController.new(state, env.registry, sr)
	gc._push_skill(99, 0, inst_id, 0)
	gc._resolve_skill_stack()

	gc.submit_choice(0, 200)
	gc.submit_choice(1, 500)

	assert_bool(gc.is_waiting_for_choice()).is_false()
	assert_bool(state.skill_stack.is_empty()).is_true()


func test_backward_compat_single_choice() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(99, "テスト", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(99, SingleTestSkill.new())
	var inst_id: int = H.place_on_stage(state, 0, 99)

	var gc := GameController.new(state, env.registry, sr)
	gc._push_skill(99, 0, inst_id, 0)
	gc._resolve_skill_stack()

	assert_int(state.pending_choices.size()).is_equal(1)

	gc.submit_choice(0, 20)

	assert_bool(gc.is_waiting_for_choice()).is_false()
	assert_bool(state.skill_stack.is_empty()).is_true()


func test_dispatched_flag() -> void:
	var pc := PendingChoice.new()
	assert_bool(pc.dispatched).is_false()
	pc.dispatched = true
	assert_bool(pc.dispatched).is_true()

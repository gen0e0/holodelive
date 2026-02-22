class_name SkillSystemTest
extends GdUnitTestSuite

# --- SkillResult ---

func test_skill_result_done() -> void:
	var r := SkillResult.done()
	assert_int(r.status).is_equal(SkillResult.Status.DONE)

func test_skill_result_waiting() -> void:
	var targets := [1, 2, 3]
	var r := SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	assert_int(r.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(r.choice_type).is_equal(Enums.ChoiceType.SELECT_CARD)
	assert_array(r.valid_targets).contains_exactly([1, 2, 3])

func test_skill_result_waiting_select_zone() -> void:
	var r := SkillResult.waiting(Enums.ChoiceType.SELECT_ZONE, ["stage_0", "backstage"])
	assert_int(r.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(r.choice_type).is_equal(Enums.ChoiceType.SELECT_ZONE)

# --- SkillContext ---

func test_skill_context_default() -> void:
	var ctx := SkillContext.new()
	assert_int(ctx.source_instance_id).is_equal(-1)
	assert_int(ctx.player).is_equal(0)
	assert_int(ctx.phase).is_equal(0)
	assert_that(ctx.choice_result).is_null()
	assert_dict(ctx.data).is_empty()

func test_skill_context_with_params() -> void:
	var state := GameState.new()
	var registry := CardRegistry.new()
	var ctx := SkillContext.new(state, registry, 5, 1, 2, "some_choice")
	assert_int(ctx.source_instance_id).is_equal(5)
	assert_int(ctx.player).is_equal(1)
	assert_int(ctx.phase).is_equal(2)
	assert_str(ctx.choice_result as String).is_equal("some_choice")

# --- SkillStackEntry ---

func test_skill_stack_entry_default() -> void:
	var entry := SkillStackEntry.new()
	assert_int(entry.card_id).is_equal(-1)
	assert_int(entry.skill_index).is_equal(0)
	assert_int(entry.source_instance_id).is_equal(-1)
	assert_int(entry.player).is_equal(0)
	assert_int(entry.phase).is_equal(0)
	assert_dict(entry.data).is_empty()
	assert_int(entry.state).is_equal(Enums.SkillState.PENDING)

func test_skill_stack_entry_phase_tracking() -> void:
	var entry := SkillStackEntry.new()
	entry.card_id = 6
	entry.skill_index = 0
	entry.phase = 0
	entry.phase += 1
	assert_int(entry.phase).is_equal(1)
	entry.data["selected_target"] = 42
	assert_int(entry.data["selected_target"]).is_equal(42)

# --- BaseCardSkill ---

func test_base_card_skill_no_method_returns_done() -> void:
	var skill := BaseCardSkill.new()
	var ctx := SkillContext.new()
	var result: SkillResult = skill.execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

func test_base_card_skill_invalid_index_returns_done() -> void:
	var skill := BaseCardSkill.new()
	var ctx := SkillContext.new()
	var result: SkillResult = skill.execute_skill(ctx, 99)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

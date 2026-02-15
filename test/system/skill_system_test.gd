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

# --- Mock Skill Script Loading & Execution ---

func test_load_and_execute_tokino_sora() -> void:
	var script = load("res://cards/001_tokino_sora/tokino_sora.gd")
	assert_that(script).is_not_null()
	var skill = script.new()
	var ctx := SkillContext.new()
	# skill_0: ぬんぬん (passive)
	var r0: SkillResult = skill.execute_skill(ctx, 0)
	assert_int(r0.status).is_equal(SkillResult.Status.DONE)
	# skill_1: 始祖 (passive)
	var r1: SkillResult = skill.execute_skill(ctx, 1)
	assert_int(r1.status).is_equal(SkillResult.Status.DONE)

func test_load_and_execute_omaru_polka() -> void:
	var script = load("res://cards/035_omaru_polka/omaru_polka.gd")
	var skill = script.new()
	var ctx := SkillContext.new()
	# skill_0: ポルカおるか？ (play)
	var r0: SkillResult = skill.execute_skill(ctx, 0)
	assert_int(r0.status).is_equal(SkillResult.Status.DONE)
	# skill_1: ポルカおらんか？ (action)
	var r1: SkillResult = skill.execute_skill(ctx, 1)
	assert_int(r1.status).is_equal(SkillResult.Status.DONE)

func test_execute_invalid_skill_index_returns_done() -> void:
	var script = load("res://cards/001_tokino_sora/tokino_sora.gd")
	var skill = script.new()
	var ctx := SkillContext.new()
	var result: SkillResult = skill.execute_skill(ctx, 99)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

func test_load_and_execute_kiryu_coco() -> void:
	var script = load("res://cards/058_kiryu_coco/kiryu_coco.gd")
	var skill = script.new()
	var ctx := SkillContext.new()
	# skill_0: 伝説のドラゴン (passive)
	var result: SkillResult = skill.execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

func test_load_and_execute_ninomae_inanis() -> void:
	var script = load("res://cards/041_ninomae_inanis/ninomae_inanis.gd")
	var skill = script.new()
	var ctx := SkillContext.new()
	# skill_0: ネクロノミコン (passive)
	var r0: SkillResult = skill.execute_skill(ctx, 0)
	assert_int(r0.status).is_equal(SkillResult.Status.DONE)
	# skill_1: ネクロノミコン (play)
	var r1: SkillResult = skill.execute_skill(ctx, 1)
	assert_int(r1.status).is_equal(SkillResult.Status.DONE)

class_name DataClassesTest
extends GdUnitTestSuite

# --- Enums ---

func test_phase_enum() -> void:
	assert_int(Enums.Phase.ACTION).is_equal(0)
	assert_int(Enums.Phase.PLAY).is_equal(1)
	assert_int(Enums.Phase.LIVE).is_equal(2)
	assert_int(Enums.Phase.SHOWDOWN).is_equal(3)

func test_action_type_enum() -> void:
	assert_int(Enums.ActionType.DRAW).is_equal(0)
	assert_int(Enums.ActionType.PASS).is_equal(9)

func test_diff_type_enum() -> void:
	assert_int(Enums.DiffType.CARD_MOVE).is_equal(0)
	assert_int(Enums.DiffType.INSTANCE_DESTROY).is_equal(6)

# --- CardDef ---

func test_card_def_default() -> void:
	var cd := CardDef.new()
	assert_int(cd.card_id).is_equal(0)
	assert_str(cd.nickname).is_equal("")
	assert_array(cd.base_icons).is_empty()
	assert_array(cd.base_suits).is_empty()

func test_card_def_with_values() -> void:
	var icons: Array[String] = ["VOCAL", "SEXY"]
	var suits: Array[String] = ["COOL"]
	var cd := CardDef.new(1, "Sora", icons, suits)
	assert_int(cd.card_id).is_equal(1)
	assert_str(cd.nickname).is_equal("Sora")
	assert_array(cd.base_icons).has_size(2)
	assert_array(cd.base_suits).has_size(1)

# --- CardInstance ---

func test_card_instance_default() -> void:
	var ci := CardInstance.new()
	assert_int(ci.instance_id).is_equal(0)
	assert_int(ci.card_id).is_equal(0)
	assert_bool(ci.face_down).is_false()
	assert_array(ci.action_skills_used).is_empty()
	assert_array(ci.modifiers).is_empty()

func test_card_instance_with_id() -> void:
	var ci := CardInstance.new(5, 3)
	assert_int(ci.instance_id).is_equal(5)
	assert_int(ci.card_id).is_equal(3)

# --- Modifier ---

func test_modifier_default() -> void:
	var m := Modifier.new()
	assert_int(m.type).is_equal(Enums.ModifierType.ICON_ADD)
	assert_str(m.value).is_equal("")
	assert_int(m.source_instance_id).is_equal(-1)
	assert_bool(m.persistent).is_false()

func test_modifier_with_values() -> void:
	var m := Modifier.new(Enums.ModifierType.SUIT_ADD, "COOL", 10, true)
	assert_int(m.type).is_equal(Enums.ModifierType.SUIT_ADD)
	assert_str(m.value).is_equal("COOL")
	assert_int(m.source_instance_id).is_equal(10)
	assert_bool(m.persistent).is_true()

# --- StateDiff ---

func test_state_diff_default() -> void:
	var sd := StateDiff.new()
	assert_int(sd.type).is_equal(Enums.DiffType.PROPERTY_CHANGE)
	assert_dict(sd.details).is_empty()

func test_state_diff_with_values() -> void:
	var details := {"instance_id": 1, "from_zone": "deck", "to_zone": "hand"}
	var sd := StateDiff.new(Enums.DiffType.CARD_MOVE, details)
	assert_int(sd.type).is_equal(Enums.DiffType.CARD_MOVE)
	assert_str(sd.details["from_zone"]).is_equal("deck")

# --- GameAction ---

func test_game_action_default() -> void:
	var ga := GameAction.new()
	assert_int(ga.type).is_equal(Enums.ActionType.DRAW)
	assert_int(ga.player).is_equal(0)
	assert_dict(ga.params).is_empty()
	assert_array(ga.diffs).is_empty()

func test_game_action_with_diffs() -> void:
	var ga := GameAction.new(Enums.ActionType.PLAY_CARD, 1, {"card": 5})
	var diff := StateDiff.new(Enums.DiffType.CARD_MOVE, {"instance_id": 5})
	ga.diffs.append(diff)
	assert_int(ga.type).is_equal(Enums.ActionType.PLAY_CARD)
	assert_int(ga.player).is_equal(1)
	assert_array(ga.diffs).has_size(1)

# --- SkillStackEntry ---

func test_skill_stack_entry_default() -> void:
	var sse := SkillStackEntry.new()
	assert_int(sse.source_instance_id).is_equal(-1)
	assert_int(sse.player).is_equal(0)
	assert_array(sse.targets).is_empty()
	assert_int(sse.state).is_equal(Enums.SkillState.PENDING)

# --- PendingChoice ---

# --- TriggerEvent ---

func test_trigger_event_enum() -> void:
	assert_int(Enums.TriggerEvent.SKILL_ACTIVATED).is_equal(0)
	assert_int(Enums.TriggerEvent.TURN_END).is_equal(5)

# --- CardDef.skills ---

func test_card_def_skills_default_empty() -> void:
	var cd := CardDef.new()
	assert_array(cd.skills).is_empty()

func test_card_def_with_skills() -> void:
	var icons: Array[String] = ["VOCAL"]
	var suits: Array[String] = ["COOL"]
	var skills := [{"name": "TestSkill", "type": Enums.SkillType.PLAY, "description": "test"}]
	var cd := CardDef.new(1, "Test", icons, suits, skills)
	assert_array(cd.skills).has_size(1)
	assert_str(cd.skills[0]["name"]).is_equal("TestSkill")

# --- SkillContext.recorder ---

func test_skill_context_recorder_default_null() -> void:
	var ctx := SkillContext.new()
	assert_that(ctx.recorder).is_null()

func test_skill_context_with_recorder() -> void:
	var rec := DiffRecorder.new()
	var ctx := SkillContext.new(null, null, -1, 0, 0, null, rec)
	assert_that(ctx.recorder).is_not_null()

# --- DiffRecorder helpers ---

func test_diff_recorder_modifier_add() -> void:
	var rec := DiffRecorder.new()
	var mod := Modifier.new(Enums.ModifierType.ICON_ADD, "VOCAL", 10, false)
	var diff := rec.record_modifier_add(5, mod)
	assert_int(diff.type).is_equal(Enums.DiffType.MODIFIER_ADD)
	assert_int(diff.details["instance_id"]).is_equal(5)
	assert_str(diff.details["value"]).is_equal("VOCAL")

func test_diff_recorder_modifier_remove() -> void:
	var rec := DiffRecorder.new()
	var mod := Modifier.new(Enums.ModifierType.SUIT_REMOVE, "HOT", 3, true)
	var diff := rec.record_modifier_remove(7, mod)
	assert_int(diff.type).is_equal(Enums.DiffType.MODIFIER_REMOVE)
	assert_int(diff.details["instance_id"]).is_equal(7)
	assert_bool(diff.details["persistent"]).is_true()

func test_diff_recorder_instance_create() -> void:
	var rec := DiffRecorder.new()
	var diff := rec.record_instance_create(100, 5)
	assert_int(diff.type).is_equal(Enums.DiffType.INSTANCE_CREATE)
	assert_int(diff.details["instance_id"]).is_equal(100)
	assert_int(diff.details["card_id"]).is_equal(5)

func test_diff_recorder_instance_destroy() -> void:
	var rec := DiffRecorder.new()
	var diff := rec.record_instance_destroy(100, 5)
	assert_int(diff.type).is_equal(Enums.DiffType.INSTANCE_DESTROY)
	assert_int(diff.details["instance_id"]).is_equal(100)

# --- BaseCardSkill._can_counter ---

func test_base_card_skill_can_counter_default_false() -> void:
	var skill := BaseCardSkill.new()
	var ctx := SkillContext.new()
	assert_bool(skill._can_counter(ctx)).is_false()

# --- PendingChoice ---

func test_pending_choice_default() -> void:
	var pc := PendingChoice.new()
	assert_int(pc.stack_index).is_equal(-1)
	assert_int(pc.skill_source_instance_id).is_equal(-1)
	assert_int(pc.target_player).is_equal(0)
	assert_int(pc.choice_type).is_equal(Enums.ChoiceType.SELECT_CARD)
	assert_array(pc.valid_targets).is_empty()
	assert_float(pc.timeout).is_equal(30.0)
	assert_str(pc.timeout_strategy).is_equal("first")
	assert_bool(pc.resolved).is_false()
	assert_that(pc.result).is_null()

func test_pending_choice_custom_timeout() -> void:
	var pc := PendingChoice.new()
	pc.timeout = 60.0
	pc.timeout_strategy = "random"
	assert_float(pc.timeout).is_equal(60.0)
	assert_str(pc.timeout_strategy).is_equal("random")

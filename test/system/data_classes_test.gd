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

func test_pending_choice_default() -> void:
	var pc := PendingChoice.new()
	assert_int(pc.stack_index).is_equal(-1)
	assert_int(pc.skill_source_instance_id).is_equal(-1)
	assert_int(pc.target_player).is_equal(0)
	assert_int(pc.choice_type).is_equal(Enums.ChoiceType.SELECT_CARD)
	assert_array(pc.valid_targets).is_empty()
	assert_bool(pc.resolved).is_false()
	assert_that(pc.result).is_null()

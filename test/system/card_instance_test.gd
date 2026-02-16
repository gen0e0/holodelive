class_name CardInstanceTest
extends GdUnitTestSuite


func _make_card_def(icons: Array[String], suits: Array[String]) -> CardDef:
	return CardDef.new(1, "Test", icons, suits)


func _make_modifier(type: Enums.ModifierType, value: String) -> Modifier:
	return Modifier.new(type, value, 100)


# --- effective_icons ---

func test_effective_icons_no_modifiers() -> void:
	var inst := CardInstance.new(1, 1)
	var def := _make_card_def(["VOCAL", "DANCE"] as Array[String], ["COOL"] as Array[String])
	var result := inst.effective_icons(def)
	assert_array(result).has_size(2)
	assert_array(result).contains(["VOCAL", "DANCE"])


func test_effective_icons_with_add() -> void:
	var inst := CardInstance.new(1, 1)
	inst.modifiers.append(_make_modifier(Enums.ModifierType.ICON_ADD, "SEXY"))
	var def := _make_card_def(["VOCAL"] as Array[String], ["COOL"] as Array[String])
	var result := inst.effective_icons(def)
	assert_array(result).has_size(2)
	assert_array(result).contains(["VOCAL", "SEXY"])


func test_effective_icons_with_remove() -> void:
	var inst := CardInstance.new(1, 1)
	inst.modifiers.append(_make_modifier(Enums.ModifierType.ICON_REMOVE, "VOCAL"))
	var def := _make_card_def(["VOCAL", "DANCE"] as Array[String], ["COOL"] as Array[String])
	var result := inst.effective_icons(def)
	assert_array(result).has_size(1)
	assert_array(result).contains(["DANCE"])


func test_effective_icons_add_and_remove() -> void:
	var inst := CardInstance.new(1, 1)
	inst.modifiers.append(_make_modifier(Enums.ModifierType.ICON_ADD, "SEXY"))
	inst.modifiers.append(_make_modifier(Enums.ModifierType.ICON_REMOVE, "VOCAL"))
	var def := _make_card_def(["VOCAL", "DANCE"] as Array[String], ["COOL"] as Array[String])
	var result := inst.effective_icons(def)
	assert_array(result).has_size(2)
	assert_array(result).contains(["DANCE", "SEXY"])


func test_effective_icons_remove_nonexistent() -> void:
	var inst := CardInstance.new(1, 1)
	inst.modifiers.append(_make_modifier(Enums.ModifierType.ICON_REMOVE, "SEXY"))
	var def := _make_card_def(["VOCAL"] as Array[String], ["COOL"] as Array[String])
	var result := inst.effective_icons(def)
	assert_array(result).has_size(1)
	assert_array(result).contains(["VOCAL"])


func test_effective_icons_remove_only_one_duplicate() -> void:
	var inst := CardInstance.new(1, 1)
	inst.modifiers.append(_make_modifier(Enums.ModifierType.ICON_REMOVE, "VOCAL"))
	var def := _make_card_def(["VOCAL", "VOCAL"] as Array[String], ["COOL"] as Array[String])
	var result := inst.effective_icons(def)
	assert_array(result).has_size(1)
	assert_str(result[0]).is_equal("VOCAL")


# --- effective_suits ---

func test_effective_suits_no_modifiers() -> void:
	var inst := CardInstance.new(1, 1)
	var def := _make_card_def(["VOCAL"] as Array[String], ["COOL", "HOT"] as Array[String])
	var result := inst.effective_suits(def)
	assert_array(result).has_size(2)
	assert_array(result).contains(["COOL", "HOT"])


func test_effective_suits_with_add() -> void:
	var inst := CardInstance.new(1, 1)
	inst.modifiers.append(_make_modifier(Enums.ModifierType.SUIT_ADD, "POP"))
	var def := _make_card_def(["VOCAL"] as Array[String], ["COOL"] as Array[String])
	var result := inst.effective_suits(def)
	assert_array(result).has_size(2)
	assert_array(result).contains(["COOL", "POP"])


func test_effective_suits_with_remove() -> void:
	var inst := CardInstance.new(1, 1)
	inst.modifiers.append(_make_modifier(Enums.ModifierType.SUIT_REMOVE, "COOL"))
	var def := _make_card_def(["VOCAL"] as Array[String], ["COOL", "HOT"] as Array[String])
	var result := inst.effective_suits(def)
	assert_array(result).has_size(1)
	assert_array(result).contains(["HOT"])

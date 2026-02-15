class_name DiffRecorderTest
extends GdUnitTestSuite

func test_record_creates_diff() -> void:
	var rec := DiffRecorder.new()
	var diff := rec.record(Enums.DiffType.PROPERTY_CHANGE, {"property_name": "phase", "before": 0, "after": 1})
	assert_array(rec.diffs).has_size(1)
	assert_int(diff.type).is_equal(Enums.DiffType.PROPERTY_CHANGE)

func test_record_card_move() -> void:
	var rec := DiffRecorder.new()
	var diff := rec.record_card_move(5, "deck", 0, "hand", 0)
	assert_int(diff.details["instance_id"]).is_equal(5)
	assert_str(diff.details["from_zone"]).is_equal("deck")
	assert_str(diff.details["to_zone"]).is_equal("hand")

func test_record_card_flip() -> void:
	var rec := DiffRecorder.new()
	var diff := rec.record_card_flip(3, false, true)
	assert_int(diff.details["instance_id"]).is_equal(3)
	assert_bool(diff.details["before"]).is_false()
	assert_bool(diff.details["after"]).is_true()

func test_record_property_change() -> void:
	var rec := DiffRecorder.new()
	var diff := rec.record_property_change("current_player", 0, 1)
	assert_str(diff.details["property_name"]).is_equal("current_player")

func test_clear() -> void:
	var rec := DiffRecorder.new()
	rec.record(Enums.DiffType.CARD_MOVE, {})
	rec.record(Enums.DiffType.CARD_FLIP, {})
	assert_array(rec.diffs).has_size(2)
	rec.clear()
	assert_array(rec.diffs).is_empty()

func test_multiple_records() -> void:
	var rec := DiffRecorder.new()
	rec.record_card_move(1, "deck", 0, "hand", 0)
	rec.record_card_flip(1, false, true)
	rec.record_property_change("phase", 0, 1)
	assert_array(rec.diffs).has_size(3)
	assert_int(rec.diffs[0].type).is_equal(Enums.DiffType.CARD_MOVE)
	assert_int(rec.diffs[1].type).is_equal(Enums.DiffType.CARD_FLIP)
	assert_int(rec.diffs[2].type).is_equal(Enums.DiffType.PROPERTY_CHANGE)

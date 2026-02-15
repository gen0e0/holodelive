class_name DiffRecorder
extends RefCounted

var diffs: Array = []  # Array[StateDiff]


func record(type: Enums.DiffType, details: Dictionary) -> StateDiff:
	var diff := StateDiff.new(type, details)
	diffs.append(diff)
	return diff


func record_card_move(instance_id: int, from_zone: String, from_index: int, to_zone: String, to_index: int) -> StateDiff:
	return record(Enums.DiffType.CARD_MOVE, {
		"instance_id": instance_id,
		"from_zone": from_zone,
		"from_index": from_index,
		"to_zone": to_zone,
		"to_index": to_index,
	})


func record_card_flip(instance_id: int, before: bool, after: bool) -> StateDiff:
	return record(Enums.DiffType.CARD_FLIP, {
		"instance_id": instance_id,
		"before": before,
		"after": after,
	})


func record_property_change(property_name: String, before: Variant, after: Variant) -> StateDiff:
	return record(Enums.DiffType.PROPERTY_CHANGE, {
		"property_name": property_name,
		"before": before,
		"after": after,
	})


func clear() -> void:
	diffs.clear()

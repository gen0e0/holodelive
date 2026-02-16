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


func record_modifier_add(instance_id: int, modifier: Modifier) -> StateDiff:
	return record(Enums.DiffType.MODIFIER_ADD, {
		"instance_id": instance_id,
		"type": modifier.type,
		"value": modifier.value,
		"source_instance_id": modifier.source_instance_id,
		"persistent": modifier.persistent,
	})


func record_modifier_remove(instance_id: int, modifier: Modifier) -> StateDiff:
	return record(Enums.DiffType.MODIFIER_REMOVE, {
		"instance_id": instance_id,
		"type": modifier.type,
		"value": modifier.value,
		"source_instance_id": modifier.source_instance_id,
		"persistent": modifier.persistent,
	})


func record_instance_create(instance_id: int, card_id: int) -> StateDiff:
	return record(Enums.DiffType.INSTANCE_CREATE, {
		"instance_id": instance_id,
		"card_id": card_id,
	})


func record_instance_destroy(instance_id: int, card_id: int) -> StateDiff:
	return record(Enums.DiffType.INSTANCE_DESTROY, {
		"instance_id": instance_id,
		"card_id": card_id,
	})


func clear() -> void:
	diffs.clear()

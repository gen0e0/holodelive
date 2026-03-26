class_name ChoiceHelper
extends RefCounted

## Static utility methods for PendingChoice handling.


static func get_active_pending_choice(pending_choices: Array) -> PendingChoice:
	for pc in pending_choices:
		if not pc.resolved:
			return pc
	return null


static func make_choice_data(
	pc: PendingChoice, state: GameState, registry: CardRegistry
) -> Dictionary:
	var details: Array = []
	if pc.choice_type == Enums.ChoiceType.RANDOM_RESULT:
		for target in pc.valid_targets:
			details.append({"value": target})
	else:
		for target in pc.valid_targets:
			if target is int and target >= 0:
				details.append(StateSerializer._card_dict(target, state, registry))
			else:
				details.append({})

	var data: Dictionary = {
		"choice_index": state.pending_choices.find(pc),
		"target_player": pc.target_player,
		"choice_type": int(pc.choice_type),
		"valid_targets": pc.valid_targets,
		"valid_target_details": details,
		"select_min": pc.select_min,
		"select_max": pc.select_max,
		"timeout": pc.timeout,
		"ui_hint": pc.ui_hint,
	}
	# play_preview:INSTANCE_ID 形式の場合、プレビュー用カード情報を付与
	if pc.ui_hint.begins_with("play_preview:"):
		var iid_str: String = pc.ui_hint.substr("play_preview:".length())
		if iid_str.is_valid_int():
			var iid: int = iid_str.to_int()
			data["preview_card"] = StateSerializer._card_dict(iid, state, registry)
	return data

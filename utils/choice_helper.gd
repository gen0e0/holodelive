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
	for target in pc.valid_targets:
		if target is int and target >= 0:
			details.append(StateSerializer._card_dict(target, state, registry))
		else:
			details.append({})

	return {
		"choice_index": state.pending_choices.find(pc),
		"target_player": pc.target_player,
		"choice_type": int(pc.choice_type),
		"valid_targets": pc.valid_targets,
		"valid_target_details": details,
		"timeout": pc.timeout,
	}

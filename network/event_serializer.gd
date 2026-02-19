class_name EventSerializer
extends RefCounted


static func serialize_events(
	actions: Array,
	for_player: int,
	state: GameState,
	registry: CardRegistry
) -> Array:
	var events: Array = []
	for ga in actions:
		var ga_typed: GameAction = ga
		var event: Dictionary = _serialize_action(ga_typed, for_player, state, registry)
		events.append(event)
	return events


static func _serialize_action(
	ga: GameAction,
	for_player: int,
	state: GameState,
	registry: CardRegistry
) -> Dictionary:
	var type_name: String = _action_type_name(ga.type)
	var event: Dictionary = {"type": type_name, "player": ga.player}

	match ga.type:
		Enums.ActionType.DRAW:
			if ga.player == for_player:
				var inst_id: int = ga.params.get("instance_id", -1)
				event["card"] = StateSerializer._card_dict(inst_id, state, registry)
			else:
				event["card"] = null

		Enums.ActionType.PLAY_CARD:
			var inst_id: int = ga.params.get("instance_id", -1)
			event["card"] = StateSerializer._card_dict(inst_id, state, registry)
			event["target"] = ga.params.get("target", "")

		Enums.ActionType.PASS:
			pass  # type and player only

		Enums.ActionType.OPEN:
			var inst_id: int = ga.params.get("instance_id", -1)
			event["card"] = StateSerializer._card_dict(inst_id, state, registry)

		Enums.ActionType.ACTIVATE_SKILL:
			var inst_id: int = ga.params.get("instance_id", -1)
			event["card"] = StateSerializer._card_dict(inst_id, state, registry)
			event["skill_index"] = ga.params.get("skill_index", 0)

		Enums.ActionType.SKILL_EFFECT:
			# Pass through all params for skill effects
			for key in ga.params:
				event[key] = ga.params[key]

		Enums.ActionType.ROUND_END:
			event["winner"] = ga.params.get("winner", -1)

		Enums.ActionType.TURN_START, Enums.ActionType.TURN_END:
			pass  # type and player only

		Enums.ActionType.ROUND_START:
			event["round_number"] = ga.params.get("round_number", 1)

	return event


static func _action_type_name(action_type: Enums.ActionType) -> String:
	match action_type:
		Enums.ActionType.DRAW: return "DRAW"
		Enums.ActionType.PLAY_CARD: return "PLAY_CARD"
		Enums.ActionType.OPEN: return "OPEN"
		Enums.ActionType.ACTIVATE_SKILL: return "ACTIVATE_SKILL"
		Enums.ActionType.SKILL_EFFECT: return "SKILL_EFFECT"
		Enums.ActionType.TURN_START: return "TURN_START"
		Enums.ActionType.TURN_END: return "TURN_END"
		Enums.ActionType.ROUND_START: return "ROUND_START"
		Enums.ActionType.ROUND_END: return "ROUND_END"
		Enums.ActionType.PASS: return "PASS"
		_: return "UNKNOWN"

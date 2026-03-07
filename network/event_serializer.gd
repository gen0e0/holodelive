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
			# Pass through all params for skill effects (except animation_cues)
			for key in ga.params:
				if key == "animation_cues":
					continue
				event[key] = ga.params[key]

			# animation_cues を直接シリアライズ
			var cues: Array = []
			for cue in ga.params.get("animation_cues", []):
				cues.append(_serialize_cue(cue, ga.player, state, registry))
			if not cues.is_empty():
				event["cues"] = cues

		Enums.ActionType.ROUND_END:
			event["winner"] = ga.params.get("winner", -1)

		Enums.ActionType.TURN_START, Enums.ActionType.TURN_END:
			pass  # type and player only

		Enums.ActionType.ROUND_START:
			event["round_number"] = ga.params.get("round_number", 1)

	return event


static func _serialize_cue(
	cue: AnimationCue,
	skill_player: int,
	state: GameState,
	registry: CardRegistry
) -> Dictionary:
	var d: Dictionary = {
		"source": cue.source,
		"instance_id": cue.instance_id,
		"action": cue.action,
		"card": StateSerializer._card_dict(cue.instance_id, state, registry),
		"style": AnimationCue.Style.keys()[cue.style],
		"from_zone": _resolve_zone(cue.from_zone, skill_player),
		"from_player": _resolve_player(cue.from_zone, skill_player),
		"to_zone": _resolve_zone(cue.to_zone, skill_player),
		"to_player": _resolve_player(cue.to_zone, skill_player),
		"face_up": cue.face_up_override,
		"delay": cue.delay,
		"duration": cue.anim_duration,
	}
	if cue.action == "flip":
		d["to_face_down"] = cue.to_face_down
	return d


## "my_hand" → "hand", "op_stage" → "stage" など、プレフィックスを除いたゾーン名を返す。
static func _resolve_zone(zone: String, _skill_player: int) -> String:
	if zone.begins_with("my_") or zone.begins_with("op_"):
		return zone.substr(zone.find("_") + 1)
	return zone  # "auto", "deck", "home", ""


## "my_*" → skill_player, "op_*" → 1-skill_player, それ以外 → -1。
static func _resolve_player(zone: String, skill_player: int) -> int:
	if zone.begins_with("my_"):
		return skill_player
	if zone.begins_with("op_"):
		return 1 - skill_player
	return -1


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

class_name DisplayHelper
extends RefCounted

## Static utility methods for formatting card/action/event data for display.


static func format_card_dict(d: Dictionary) -> String:
	if d.get("hidden", false):
		return "<hidden>"
	var card_id: int = d.get("card_id", -1)
	var nickname: String = d.get("nickname", "?")
	var icons: Array = d.get("icons", [])
	var suits: Array = d.get("suits", [])
	var icon_abbrs: Array[String] = []
	for ic in icons:
		icon_abbrs.append(str(ic).left(3))
	var suit_abbrs: Array[String] = []
	for su in suits:
		suit_abbrs.append(str(su).left(3))
	return "<#%03d %s %s-%s>" % [
		card_id,
		nickname.left(3),
		",".join(icon_abbrs),
		",".join(suit_abbrs)
	]


static func format_action(action: Dictionary, cs: ClientState) -> String:
	var atype: Enums.ActionType = action["type"]
	match atype:
		Enums.ActionType.PASS:
			return "Pass"
		Enums.ActionType.OPEN:
			var card_str: String = lookup_card_label(action.get("instance_id", -1), cs)
			return "Open backstage %s" % card_str
		Enums.ActionType.PLAY_CARD:
			var target: String = action.get("target", "")
			var card_str: String = lookup_card_label(action.get("instance_id", -1), cs)
			if target == "stage":
				return "Play %s -> Stage" % card_str
			else:
				return "Play %s -> Backstage" % card_str
		Enums.ActionType.ACTIVATE_SKILL:
			var skill_idx: int = action.get("skill_index", 0)
			var card_str: String = lookup_card_label(action.get("instance_id", -1), cs)
			return "Activate skill #%d of %s" % [skill_idx, card_str]
		_:
			return str(action)


static func format_event(event: Dictionary, cs: ClientState) -> String:
	var type: String = event.get("type", "")
	var player: int = event.get("player", 0)
	var turn: int = cs.turn_number if cs else 0
	var prefix: String = "[T%d] P%d: " % [turn, player]

	match type:
		"DRAW":
			var card: Variant = event.get("card")
			if card != null:
				return prefix + "Drew %s" % format_card_dict(card)
			else:
				return prefix + "Drew a card"
		"PASS":
			var phase_name: String = get_phase_name(cs.phase) if cs else "?"
			return prefix + "Pass (%s)" % phase_name
		"OPEN":
			var card: Variant = event.get("card")
			if card != null:
				return prefix + "Opened backstage %s" % format_card_dict(card)
			return prefix + "Opened backstage"
		"PLAY_CARD":
			var card: Variant = event.get("card")
			var target: String = event.get("target", "")
			var card_str: String = format_card_dict(card) if card != null else "?"
			if target == "stage":
				return prefix + "Played %s -> Stage" % card_str
			else:
				return prefix + "Played %s -> Backstage" % card_str
		"ACTIVATE_SKILL":
			var card: Variant = event.get("card")
			var card_str: String = format_card_dict(card) if card != null else "?"
			return prefix + "Activated skill of %s" % card_str
		"ROUND_END":
			var winner: int = event.get("winner", -1)
			if cs:
				return "[color=yellow]--- Round End: Player %d wins! (P0=%d P1=%d) ---[/color]" % [
					winner, cs.round_wins[0], cs.round_wins[1]
				]
			return "[color=yellow]--- Round End: Player %d wins! ---[/color]" % winner
		"TURN_START":
			return ""
		"TURN_END":
			return ""

	return ""


static func lookup_card_label(instance_id: int, cs: ClientState) -> String:
	if cs == null:
		return "#?"
	for d in cs.my_hand:
		if d.get("instance_id", -1) == instance_id:
			return format_card_dict(d)
	for p in range(2):
		for d in cs.stages[p]:
			if d.get("instance_id", -1) == instance_id:
				return format_card_dict(d)
		if cs.backstages[p] != null:
			var d: Dictionary = cs.backstages[p]
			if d.get("instance_id", -1) == instance_id:
				return format_card_dict(d)
	for d in cs.home:
		if d.get("instance_id", -1) == instance_id:
			return format_card_dict(d)
	for d in cs.removed:
		if d.get("instance_id", -1) == instance_id:
			return format_card_dict(d)
	return "#?"


static func get_phase_name(phase: Enums.Phase) -> String:
	match phase:
		Enums.Phase.ACTION: return "ACTION"
		Enums.Phase.PLAY: return "PLAY"
		Enums.Phase.LIVE: return "LIVE"
		Enums.Phase.SHOWDOWN: return "SHOWDOWN"
		_: return "?"

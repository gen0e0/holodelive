class_name StateSerializer
extends RefCounted


static func serialize_for_player(state: GameState, player: int, registry: CardRegistry) -> ClientState:
	var cs := ClientState.new()
	cs.my_player = player
	var opponent: int = 1 - player

	# Hand: own hand gets full details, opponent hand gets count only
	var my_hand_ids: Array = state.hands[player]
	for inst_id in my_hand_ids:
		cs.my_hand.append(_card_dict(inst_id, state, registry))
	cs.opponent_hand_count = state.hands[opponent].size()

	# Stages: visible cards get details, face_down cards get {instance_id, hidden: true}
	cs.stages = [[], []]
	for p in range(2):
		for inst_id in state.stages[p]:
			var inst: CardInstance = state.instances.get(inst_id)
			if inst and inst.face_down:
				cs.stages[p].append({"instance_id": inst_id, "hidden": true})
			else:
				cs.stages[p].append(_card_dict(inst_id, state, registry))

	# Backstages
	cs.backstages = [null, null]
	for p in range(2):
		var bs_id: int = state.backstages[p]
		if bs_id == -1:
			cs.backstages[p] = null
		elif p == player:
			# Own backstage: always show details
			cs.backstages[p] = _card_dict(bs_id, state, registry)
		else:
			# Opponent backstage: hidden if face_down
			var inst: CardInstance = state.instances.get(bs_id)
			if inst and inst.face_down:
				cs.backstages[p] = {"instance_id": bs_id, "hidden": true}
			else:
				cs.backstages[p] = _card_dict(bs_id, state, registry)

	# Deck: count only
	cs.deck_count = state.deck.size()

	# Home and removed: public zones, full details
	for inst_id in state.home:
		cs.home.append(_card_dict(inst_id, state, registry))
	for inst_id in state.removed:
		cs.removed.append(_card_dict(inst_id, state, registry))

	# Scalar fields
	cs.current_player = state.current_player
	cs.phase = state.phase
	cs.round_number = state.round_number
	cs.turn_number = state.turn_number
	cs.round_wins = [state.round_wins[0], state.round_wins[1]]
	cs.live_ready = [state.live_ready[0], state.live_ready[1]]
	cs.live_ready_turn = [state.live_ready_turn[0], state.live_ready_turn[1]]

	return cs


static func _card_dict(instance_id: int, state: GameState, registry: CardRegistry) -> Dictionary:
	var inst: CardInstance = state.instances.get(instance_id)
	if inst == null:
		return {"instance_id": instance_id, "card_id": -1, "nickname": "?", "icons": [], "suits": []}
	var card_def: CardDef = registry.get_card(inst.card_id)
	if card_def == null:
		return {"instance_id": instance_id, "card_id": inst.card_id, "nickname": "?", "icons": [], "suits": []}
	var icons: Array[String] = inst.effective_icons(card_def)
	var suits: Array[String] = inst.effective_suits(card_def)
	var image_path: String = card_def.dir_path + "/img_card.png"
	return {
		"instance_id": instance_id,
		"card_id": inst.card_id,
		"nickname": card_def.nickname,
		"icons": icons,
		"suits": suits,
		"image_path": image_path,
	}

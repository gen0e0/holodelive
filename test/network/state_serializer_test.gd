class_name StateSerializerTest
extends GdUnitTestSuite


func _create_state() -> Dictionary:
	var registry := CardFactory.create_test_registry(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state := GameSetup.setup_game(registry, rng)
	return {"state": state, "registry": registry}


func test_own_hand_has_card_details() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]
	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)

	assert_int(cs.my_hand.size()).is_equal(state.hands[0].size())
	for card_dict in cs.my_hand:
		var d: Dictionary = card_dict
		assert_bool(d.has("instance_id")).is_true()
		assert_bool(d.has("card_id")).is_true()
		assert_bool(d.has("nickname")).is_true()
		assert_bool(d.has("icons")).is_true()
		assert_bool(d.has("suits")).is_true()
		assert_str(d["nickname"]).is_not_empty()


func test_opponent_hand_count_only() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]
	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)

	assert_int(cs.opponent_hand_count).is_equal(state.hands[1].size())


func test_face_up_stage_shows_details() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	# Place a card on stage face-up
	var inst_id: int = state.hands[0][0]
	state.hands[0].erase(inst_id)
	state.stages[0].append(inst_id)
	var inst: CardInstance = state.instances[inst_id]
	inst.face_down = false

	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)
	var stage_cards: Array = cs.stages[0]
	assert_int(stage_cards.size()).is_greater(0)
	var card_dict: Dictionary = stage_cards[0]
	assert_bool(card_dict.has("nickname")).is_true()
	assert_bool(card_dict.get("hidden", false)).is_false()


func test_face_down_stage_shows_hidden() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	# Place a card on stage face-down
	var inst_id: int = state.hands[0][0]
	state.hands[0].erase(inst_id)
	state.stages[0].append(inst_id)
	var inst: CardInstance = state.instances[inst_id]
	inst.face_down = true

	var cs: ClientState = StateSerializer.serialize_for_player(state, 1, registry)
	var stage_cards: Array = cs.stages[0]
	assert_int(stage_cards.size()).is_greater(0)
	var card_dict: Dictionary = stage_cards[0]
	assert_bool(card_dict.get("hidden", false)).is_true()
	assert_int(card_dict["instance_id"]).is_equal(inst_id)


func test_own_backstage_details() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	# Place a card in backstage face-down
	var inst_id: int = state.hands[0][0]
	state.hands[0].erase(inst_id)
	state.backstages[0] = inst_id
	var inst: CardInstance = state.instances[inst_id]
	inst.face_down = true

	# Own backstage: always visible
	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)
	assert_that(cs.backstages[0]).is_not_null()
	var d: Dictionary = cs.backstages[0]
	assert_bool(d.has("nickname")).is_true()
	assert_bool(d.get("hidden", false)).is_false()


func test_opponent_backstage_hidden() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	# Place a card in opponent's backstage face-down
	var inst_id: int = state.hands[1][0]
	state.hands[1].erase(inst_id)
	state.backstages[1] = inst_id
	var inst: CardInstance = state.instances[inst_id]
	inst.face_down = true

	# From player 0's view, opponent backstage should be hidden
	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)
	assert_that(cs.backstages[1]).is_not_null()
	var d: Dictionary = cs.backstages[1]
	assert_bool(d.get("hidden", false)).is_true()


func test_deck_count_only() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]
	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)

	assert_int(cs.deck_count).is_equal(state.deck.size())


func test_home_and_removed_public() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	# Move a card to home
	var inst_id: int = state.deck[0]
	state.deck.erase(inst_id)
	state.home.append(inst_id)

	# Move another to removed
	var inst_id2: int = state.deck[0]
	state.deck.erase(inst_id2)
	state.removed.append(inst_id2)

	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)
	assert_int(cs.home.size()).is_equal(1)
	assert_int(cs.removed.size()).is_equal(1)

	var home_card: Dictionary = cs.home[0]
	assert_bool(home_card.has("nickname")).is_true()
	assert_int(home_card["instance_id"]).is_equal(inst_id)

	var removed_card: Dictionary = cs.removed[0]
	assert_bool(removed_card.has("nickname")).is_true()
	assert_int(removed_card["instance_id"]).is_equal(inst_id2)


func test_to_dict_from_dict_roundtrip() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]
	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)

	var dict: Dictionary = cs.to_dict()
	var cs2: ClientState = ClientState.from_dict(dict)

	assert_int(cs2.my_player).is_equal(cs.my_player)
	assert_int(cs2.opponent_hand_count).is_equal(cs.opponent_hand_count)
	assert_int(cs2.deck_count).is_equal(cs.deck_count)
	assert_int(cs2.current_player).is_equal(cs.current_player)
	assert_int(cs2.phase).is_equal(cs.phase)
	assert_int(cs2.round_number).is_equal(cs.round_number)
	assert_int(cs2.turn_number).is_equal(cs.turn_number)
	assert_int(cs2.my_hand.size()).is_equal(cs.my_hand.size())
	assert_array(cs2.round_wins).is_equal(cs.round_wins)
	assert_array(cs2.live_ready).is_equal(cs.live_ready)
	assert_array(cs2.live_ready_turn).is_equal(cs.live_ready_turn)

	# Verify card dicts in hand are preserved
	for i in range(cs.my_hand.size()):
		var orig: Dictionary = cs.my_hand[i]
		var copy: Dictionary = cs2.my_hand[i]
		assert_int(copy["instance_id"]).is_equal(orig["instance_id"])
		assert_int(copy["card_id"]).is_equal(orig["card_id"])


func test_modifier_reflected() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	# Add a modifier to a card in hand
	var inst_id: int = state.hands[0][0]
	var inst: CardInstance = state.instances[inst_id]
	var card_def: CardDef = registry.get_card(inst.card_id)
	var base_icon_count: int = card_def.base_icons.size()

	# Add an icon modifier
	var mod := Modifier.new(Enums.ModifierType.ICON_ADD, "VOCAL", -1, false)
	inst.modifiers.append(mod)

	var cs: ClientState = StateSerializer.serialize_for_player(state, 0, registry)
	var card_dict: Dictionary = cs.my_hand[0]
	var icons: Array = card_dict["icons"]
	# effective_icons should reflect the added modifier
	assert_int(icons.size()).is_greater(base_icon_count)

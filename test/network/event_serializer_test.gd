class_name EventSerializerTest
extends GdUnitTestSuite


func _create_state() -> Dictionary:
	var registry := CardFactory.create_test_registry(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state := GameSetup.setup_game(registry, rng)
	return {"state": state, "registry": registry}


func test_draw_own_card_has_details() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	var inst_id: int = state.hands[0][0]
	var ga := GameAction.new(Enums.ActionType.DRAW, 0, {"instance_id": inst_id})
	var actions: Array = [ga]

	var events: Array = EventSerializer.serialize_events(actions, 0, state, registry)
	assert_int(events.size()).is_equal(1)

	var event: Dictionary = events[0]
	assert_str(event["type"]).is_equal("DRAW")
	assert_int(event["player"]).is_equal(0)
	assert_that(event["card"]).is_not_null()
	var card: Dictionary = event["card"]
	assert_bool(card.has("nickname")).is_true()
	assert_int(card["instance_id"]).is_equal(inst_id)


func test_draw_opponent_card_hidden() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	var inst_id: int = state.hands[1][0]
	var ga := GameAction.new(Enums.ActionType.DRAW, 1, {"instance_id": inst_id})
	var actions: Array = [ga]

	# Serialized for player 0 — opponent's draw should hide card
	var events: Array = EventSerializer.serialize_events(actions, 0, state, registry)
	var event: Dictionary = events[0]
	assert_str(event["type"]).is_equal("DRAW")
	assert_that(event["card"]).is_null()


func test_play_card_always_visible() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	var inst_id: int = state.hands[1][0]
	var ga := GameAction.new(Enums.ActionType.PLAY_CARD, 1, {"instance_id": inst_id, "target": "stage"})
	var actions: Array = [ga]

	# Even for opponent, PLAY_CARD shows card details
	var events: Array = EventSerializer.serialize_events(actions, 0, state, registry)
	var event: Dictionary = events[0]
	assert_str(event["type"]).is_equal("PLAY_CARD")
	assert_that(event["card"]).is_not_null()
	var card: Dictionary = event["card"]
	assert_bool(card.has("nickname")).is_true()
	assert_str(event["target"]).is_equal("stage")


func test_pass_event() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	var ga := GameAction.new(Enums.ActionType.PASS, 0, {})
	var actions: Array = [ga]

	var events: Array = EventSerializer.serialize_events(actions, 0, state, registry)
	var event: Dictionary = events[0]
	assert_str(event["type"]).is_equal("PASS")
	assert_int(event["player"]).is_equal(0)
	# PASS should only have type and player
	assert_int(event.size()).is_equal(2)


func test_round_end_event() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	var ga := GameAction.new(Enums.ActionType.ROUND_END, 0, {"winner": 1})
	var actions: Array = [ga]

	var events: Array = EventSerializer.serialize_events(actions, 0, state, registry)
	var event: Dictionary = events[0]
	assert_str(event["type"]).is_equal("ROUND_END")
	assert_int(event["winner"]).is_equal(1)


func test_multiple_actions() -> void:
	var data: Dictionary = _create_state()
	var state: GameState = data["state"]
	var registry: CardRegistry = data["registry"]

	var ga1 := GameAction.new(Enums.ActionType.TURN_START, 0, {})
	var inst_id: int = state.hands[0][0]
	var ga2 := GameAction.new(Enums.ActionType.DRAW, 0, {"instance_id": inst_id})
	var ga3 := GameAction.new(Enums.ActionType.PASS, 0, {})
	var actions: Array = [ga1, ga2, ga3]

	var events: Array = EventSerializer.serialize_events(actions, 0, state, registry)
	assert_int(events.size()).is_equal(3)
	assert_str(events[0]["type"]).is_equal("TURN_START")
	assert_str(events[1]["type"]).is_equal("DRAW")
	assert_str(events[2]["type"]).is_equal("PASS")

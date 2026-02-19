class_name LocalGameSessionTest
extends GdUnitTestSuite


func test_start_game_emits_signals() -> void:
	var session := LocalGameSession.new()

	# Use arrays to work around GDScript lambda capture-by-value for primitives
	var counts: Array[int] = [0, 0, 0]  # [started, state_updated, actions_received]
	session.game_started.connect(func() -> void: counts[0] += 1)
	session.state_updated.connect(func(_cs: ClientState, _ev: Array) -> void: counts[1] += 1)
	session.actions_received.connect(func(_a: Array) -> void: counts[2] += 1)

	session.start_game()

	# game_started should fire once
	assert_int(counts[0]).is_equal(1)
	# state_updated should fire at least once (from _do_start_turn -> _flush_updates)
	assert_int(counts[1]).is_greater(0)
	# actions_received should fire once (available actions after start_turn)
	assert_int(counts[2]).is_greater(0)


func test_send_action_updates_state() -> void:
	var session := LocalGameSession.new()

	var update_counts: Array[int] = [0]
	var last_states: Array = [null]
	session.state_updated.connect(func(cs: ClientState, _ev: Array) -> void:
		update_counts[0] += 1
		last_states[0] = cs
	)

	session.start_game()
	var before_count: int = update_counts[0]

	# Send PASS action in ACTION phase
	session.send_action({"type": Enums.ActionType.PASS})

	assert_int(update_counts[0]).is_greater(before_count)
	assert_that(last_states[0]).is_not_null()


func test_get_client_state_returns_current() -> void:
	var session := LocalGameSession.new()
	session.start_game()

	var cs: ClientState = session.get_client_state()
	assert_that(cs).is_not_null()
	assert_int(cs.round_number).is_equal(1)
	assert_int(cs.turn_number).is_equal(1)


func test_get_available_actions_nonempty() -> void:
	var session := LocalGameSession.new()
	session.start_game()

	var actions: Array = session.get_available_actions()
	assert_int(actions.size()).is_greater(0)


func test_full_game_through_session() -> void:
	var session := LocalGameSession.new()

	var winner_holder: Array[int] = [-1]
	session.game_over.connect(func(winner: int) -> void: winner_holder[0] = winner)

	# Use a seeded setup for reproducibility
	var registry := CardFactory.create_test_registry(40)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	session.registry = registry
	session.skill_registry = SkillRegistry.new()
	session.state = GameSetup.setup_game(registry, rng)
	session.controller = GameController.new(session.state, registry, session.skill_registry)
	session._last_log_index = 0
	session._client_state = null

	session.game_started.emit()
	session._do_start_turn()

	var max_iterations := 500
	var iterations := 0

	while winner_holder[0] == -1 and iterations < max_iterations:
		iterations += 1

		if session.controller.is_game_over():
			break

		var actions: Array = session.get_available_actions()
		if actions.is_empty():
			break

		# Strategy: PASS in ACTION phase, play to stage in PLAY phase
		var action_to_send: Dictionary = {}
		var played := false
		for a in actions:
			if a["type"] == Enums.ActionType.PLAY_CARD and a.get("target", "") == "stage":
				action_to_send = a
				played = true
				break
		if not played:
			for a in actions:
				if a["type"] == Enums.ActionType.PLAY_CARD:
					action_to_send = a
					played = true
					break
		if not played:
			action_to_send = {"type": Enums.ActionType.PASS}

		session.send_action(action_to_send)

	assert_int(winner_holder[0]).is_greater_equal(0)
	assert_int(winner_holder[0]).is_less_equal(1)
	assert_bool(iterations < max_iterations).is_true()

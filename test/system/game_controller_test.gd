class_name GameControllerTest
extends GdUnitTestSuite

func _setup_game(deck_size: int = 10, seed_val: int = 42) -> GameController:
	var registry := CardFactory.create_test_registry(deck_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var state := GameSetup.setup_game(registry, rng)
	return GameController.new(state, registry)

# --- start_turn ---

func test_start_turn_draws_card() -> void:
	var ctrl := _setup_game()
	var hand_before: int = ctrl.state.hands[0].size()
	ctrl.start_turn()
	assert_int(ctrl.state.hands[0].size()).is_equal(hand_before + 1)
	assert_int(ctrl.state.phase).is_equal(Enums.Phase.ACTION)

func test_start_turn_action_log() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	# TURN_START + DRAW = 2 entries
	var log_types: Array = []
	for ga in ctrl.state.action_log:
		log_types.append(ga.type)
	assert_bool(log_types.has(Enums.ActionType.TURN_START)).is_true()
	assert_bool(log_types.has(Enums.ActionType.DRAW)).is_true()

# --- get_available_actions ---

func test_action_phase_has_pass() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	var actions := ctrl.get_available_actions()
	var has_pass := false
	for a in actions:
		if a["type"] == Enums.ActionType.PASS:
			has_pass = true
	assert_bool(has_pass).is_true()

func test_action_phase_no_open_when_backstage_empty() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	# Backstage is empty at start
	var actions := ctrl.get_available_actions()
	var has_open := false
	for a in actions:
		if a["type"] == Enums.ActionType.OPEN:
			has_open = true
	assert_bool(has_open).is_false()

func test_play_phase_has_play_options() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	# Pass ACTION → move to PLAY
	ctrl.apply_action({"type": Enums.ActionType.PASS})
	assert_int(ctrl.state.phase).is_equal(Enums.Phase.PLAY)
	var actions := ctrl.get_available_actions()
	var has_play := false
	for a in actions:
		if a["type"] == Enums.ActionType.PLAY_CARD:
			has_play = true
	assert_bool(has_play).is_true()

# --- apply_action ---

func test_pass_action_to_play_phase() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	ctrl.apply_action({"type": Enums.ActionType.PASS})
	assert_int(ctrl.state.phase).is_equal(Enums.Phase.PLAY)

func test_play_card_to_stage() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	ctrl.apply_action({"type": Enums.ActionType.PASS})
	# Now in PLAY phase, play first card to stage slot 0
	var hand: Array = ctrl.state.hands[0]
	var card_to_play: int = hand[0]
	ctrl.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": card_to_play, "target": "stage"})
	assert_bool(ctrl.state.stages[0].has(card_to_play)).is_true()

func test_play_card_to_backstage() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	ctrl.apply_action({"type": Enums.ActionType.PASS})
	var hand: Array = ctrl.state.hands[0]
	var card_to_play: int = hand[0]
	ctrl.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": card_to_play, "target": "backstage"})
	assert_int(ctrl.state.backstages[0]).is_equal(card_to_play)
	assert_bool(ctrl.state.instances[card_to_play].face_down).is_true()

# --- end_turn ---

func test_end_turn_switches_player() -> void:
	var ctrl := _setup_game()
	ctrl.start_turn()
	ctrl.apply_action({"type": Enums.ActionType.PASS})
	var hand: Array = ctrl.state.hands[0]
	var card_to_play: int = hand[0]
	ctrl.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": card_to_play, "target": "stage"})
	# After play, turn should end and switch to player 1
	assert_int(ctrl.state.current_player).is_equal(1)

func test_turn_increments() -> void:
	var ctrl := _setup_game()
	assert_int(ctrl.state.turn_number).is_equal(1)
	ctrl.start_turn()
	ctrl.apply_action({"type": Enums.ActionType.PASS})
	var hand: Array = ctrl.state.hands[0]
	ctrl.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": hand[0], "target": "stage"})
	assert_int(ctrl.state.turn_number).is_equal(2)

# --- live ready ---

func test_live_ready_when_stage_full() -> void:
	var ctrl := _setup_game(20)
	# Manually fill stage for player 0
	for i in range(3):
		var id := ctrl.state.create_instance(100 + i)
		ctrl.state.stages[0].append(id)
	ctrl.state.turn_number = 5
	# Trigger end_turn to check live ready
	ctrl.end_turn()
	assert_bool(ctrl.state.live_ready[0]).is_true()
	assert_int(ctrl.state.live_ready_turn[0]).is_equal(5)

# --- home overflow ---

func test_home_overflow_removes_oldest() -> void:
	var ctrl := _setup_game(20)
	# Put 7 cards in home
	for i in range(7):
		var id := ctrl.state.create_instance(200 + i)
		ctrl.state.home.append(id)
	ctrl.end_turn()
	# Should be trimmed to 5
	assert_int(ctrl.state.home.size()).is_less_equal(5)

# --- open backstage ---

func test_open_backstage_action() -> void:
	var ctrl := _setup_game()
	# Put a face-down card in backstage
	var id := ctrl.state.create_instance(50)
	ctrl.state.backstages[0] = id
	ctrl.state.instances[id].face_down = true
	ctrl.start_turn()
	# Should have open option
	var actions := ctrl.get_available_actions()
	var has_open := false
	for a in actions:
		if a["type"] == Enums.ActionType.OPEN:
			has_open = true
	assert_bool(has_open).is_true()
	# Apply open
	ctrl.apply_action({"type": Enums.ActionType.OPEN, "instance_id": id})
	assert_bool(ctrl.state.instances[id].face_down).is_false()
	# Still in ACTION phase after open
	assert_int(ctrl.state.phase).is_equal(Enums.Phase.ACTION)

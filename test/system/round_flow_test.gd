class_name RoundFlowTest
extends GdUnitTestSuite

func _make_ctrl(deck_size: int = 20) -> GameController:
	var registry := CardFactory.create_test_registry(deck_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state := GameSetup.setup_game(registry, rng)
	return GameController.new(state, registry)

func _fill_stage(state: GameState, player: int, card_ids: Array) -> void:
	for i in range(card_ids.size()):
		var id := state.create_instance(card_ids[i])
		state.stages[player][i] = id

# --- round cleanup ---

func test_round_cleanup_removes_stage_cards() -> void:
	var ctrl := _make_ctrl()
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	_fill_stage(ctrl.state, 1, [3, 4, 5])
	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready_turn[0] = 1
	ctrl.state.current_player = 0

	var old_stage_ids: Array = []
	for s in range(3):
		old_stage_ids.append(ctrl.state.stages[0][s])

	ctrl.start_turn()  # triggers live → auto win → cleanup

	# Stage should be cleared
	for s in range(3):
		# Old cards are removed, backstage cards may have moved to slot 0
		if s > 0:
			assert_int(ctrl.state.stages[0][s]).is_equal(-1)

	# Old stage cards should be in removed
	for id in old_stage_ids:
		assert_bool(ctrl.state.removed.has(id)).is_true()

func test_round_cleanup_moves_backstage_to_stage() -> void:
	var ctrl := _make_ctrl()
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	var bs_id := ctrl.state.create_instance(10)
	ctrl.state.backstages[1] = bs_id
	ctrl.state.instances[bs_id].face_down = true

	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready_turn[0] = 1
	ctrl.state.current_player = 0

	ctrl.start_turn()

	# Player 1's backstage should have moved to stage slot 0
	assert_int(ctrl.state.stages[1][0]).is_equal(bs_id)
	assert_int(ctrl.state.backstages[1]).is_equal(-1)

func test_round_cleanup_resets_live_ready() -> void:
	var ctrl := _make_ctrl()
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready[1] = true
	ctrl.state.live_ready_turn[0] = 1
	ctrl.state.live_ready_turn[1] = 2
	ctrl.state.current_player = 0

	ctrl.start_turn()

	assert_bool(ctrl.state.live_ready[0]).is_false()
	assert_bool(ctrl.state.live_ready[1]).is_false()
	assert_int(ctrl.state.live_ready_turn[0]).is_equal(-1)

func test_round_number_increments() -> void:
	var ctrl := _make_ctrl()
	assert_int(ctrl.state.round_number).is_equal(1)
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready_turn[0] = 1
	ctrl.state.current_player = 0

	ctrl.start_turn()
	assert_int(ctrl.state.round_number).is_equal(2)

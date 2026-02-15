class_name ShowdownTest
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

# --- _trigger_live: 自動勝利 ---

func test_live_auto_win_when_opponent_not_ready() -> void:
	var ctrl := _make_ctrl()
	# Player 0 のステージを埋めてライブレディにする
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready_turn[0] = 3
	ctrl.state.current_player = 0

	var triggered := ctrl.start_turn()
	assert_bool(triggered).is_true()
	assert_int(ctrl.state.round_wins[0]).is_equal(1)
	assert_int(ctrl.state.round_wins[1]).is_equal(0)

# --- _trigger_live: ショウダウン ---

func test_showdown_higher_icons_wins() -> void:
	var ctrl := _make_ctrl()
	# Player 0: 3 cards with 1 icon each (from factory) = 3 icons
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	# Player 1: 3 cards with 1 icon each = 3 icons
	_fill_stage(ctrl.state, 1, [3, 4, 5])

	# Give player 0 an extra card in backstage (open) to get more icons
	var extra_id := ctrl.state.create_instance(6)
	ctrl.state.backstages[0] = extra_id
	ctrl.state.instances[extra_id].face_down = false

	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready[1] = true
	ctrl.state.live_ready_turn[0] = 2
	ctrl.state.live_ready_turn[1] = 3
	ctrl.state.current_player = 0

	ctrl.start_turn()
	# Player 0 has 4 icons vs Player 1 has 3 icons → Player 0 wins
	assert_int(ctrl.state.round_wins[0]).is_equal(1)
	assert_int(ctrl.state.round_wins[1]).is_equal(0)

func test_showdown_tie_earlier_live_ready_wins() -> void:
	var ctrl := _make_ctrl()
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	_fill_stage(ctrl.state, 1, [3, 4, 5])
	# Same icon count (3 each), player 1 was ready earlier
	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready[1] = true
	ctrl.state.live_ready_turn[0] = 5
	ctrl.state.live_ready_turn[1] = 3
	ctrl.state.current_player = 0

	ctrl.start_turn()
	# Tie → player 1 was ready earlier → player 1 wins
	assert_int(ctrl.state.round_wins[1]).is_equal(1)

func test_showdown_backstage_face_down_excluded() -> void:
	var ctrl := _make_ctrl()
	_fill_stage(ctrl.state, 0, [0, 1, 2])
	_fill_stage(ctrl.state, 1, [3, 4, 5])

	# Player 0 has backstage card but face_down → doesn't count
	var bs_id := ctrl.state.create_instance(6)
	ctrl.state.backstages[0] = bs_id
	ctrl.state.instances[bs_id].face_down = true

	ctrl.state.live_ready[0] = true
	ctrl.state.live_ready[1] = true
	ctrl.state.live_ready_turn[0] = 2
	ctrl.state.live_ready_turn[1] = 3
	ctrl.state.current_player = 0

	ctrl.start_turn()
	# 3 vs 3 (backstage doesn't count), tie → player 0 was ready earlier
	assert_int(ctrl.state.round_wins[0]).is_equal(1)

# --- is_game_over / get_winner ---

func test_game_not_over_initially() -> void:
	var ctrl := _make_ctrl()
	assert_bool(ctrl.is_game_over()).is_false()
	assert_int(ctrl.get_winner()).is_equal(-1)

func test_game_over_at_3_wins() -> void:
	var ctrl := _make_ctrl()
	ctrl.state.round_wins[1] = 3
	assert_bool(ctrl.is_game_over()).is_true()
	assert_int(ctrl.get_winner()).is_equal(1)

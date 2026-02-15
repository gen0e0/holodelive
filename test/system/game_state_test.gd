class_name GameStateTest
extends GdUnitTestSuite

func test_initial_state() -> void:
	var state := GameState.new()
	assert_array(state.players).is_empty()

func test_add_player() -> void:
	var state := GameState.new()
	var player := PlayerState.new()
	player.index = 0
	state.players.append(player)
	assert_array(state.players).has_size(1)
	assert_int(state.players[0].index).is_equal(0)

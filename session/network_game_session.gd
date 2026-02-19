class_name NetworkGameSession
extends GameSession

var _client: GameClient


func _init(client: GameClient) -> void:
	_client = client
	_client.state_updated.connect(func(cs: ClientState, ev: Array) -> void: state_updated.emit(cs, ev))
	_client.actions_received.connect(func(a: Array) -> void: actions_received.emit(a))
	_client.choice_requested.connect(func(cd: Dictionary) -> void: choice_requested.emit(cd))
	_client.game_started.connect(func() -> void: game_started.emit())
	_client.game_over.connect(func(w: int) -> void: game_over.emit(w))


func send_action(action: Dictionary) -> void:
	_client.send_action(action)


func send_choice(choice_idx: int, value: Variant) -> void:
	_client.send_choice(choice_idx, int(value))


func get_client_state() -> ClientState:
	return _client._client_state


func get_available_actions() -> Array:
	return _client._current_actions


func is_my_turn() -> bool:
	var cs: ClientState = get_client_state()
	if cs == null:
		return false
	return cs.current_player == cs.my_player


func start_game() -> void:
	# For network sessions, game is started by the server
	pass

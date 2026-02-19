class_name GameClient
extends Node

signal state_updated(client_state: ClientState, events: Array)
signal actions_received(actions: Array)
signal choice_requested(choice_data: Dictionary)
signal game_started()
signal game_over(winner: int)

var _client_state: ClientState = null
var _current_actions: Array = []


# =============================================================================
# Send to server (called by UI / NetworkGameSession)
# =============================================================================

func send_action(action: Dictionary) -> void:
	var nm: Node = get_parent()
	if nm.is_host:
		# Host: forward directly to local GameServer
		_deliver_action(action, 0)
	else:
		# Guest: send via RPC → host's GameClient receives it
		_request_action.rpc_id(1, action)


func send_choice(choice_idx: int, value: int) -> void:
	var nm: Node = get_parent()
	if nm.is_host:
		_deliver_choice(choice_idx, value, 0)
	else:
		_request_choice.rpc_id(1, choice_idx, value)


# =============================================================================
# RPC: client → server direction (received on host's GameClient)
# =============================================================================

@rpc("any_peer", "reliable")
func _request_action(action: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var nm: Node = get_parent()
	var player_index: int = nm.get_player_index(sender_id)
	_deliver_action(action, player_index)


@rpc("any_peer", "reliable")
func _request_choice(choice_idx: int, value: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var nm: Node = get_parent()
	var player_index: int = nm.get_player_index(sender_id)
	_deliver_choice(choice_idx, value, player_index)


func _deliver_action(action: Dictionary, player_index: int) -> void:
	var nm: Node = get_parent()
	var server: GameServer = nm.get_server()
	if server:
		server.receive_action(action, player_index)


func _deliver_choice(choice_idx: int, value: int, player_index: int) -> void:
	var nm: Node = get_parent()
	var server: GameServer = nm.get_server()
	if server:
		server.receive_choice(choice_idx, value, player_index)


# =============================================================================
# RPC: server → client direction (received from host's GameServer via helpers)
# =============================================================================

@rpc("authority", "reliable")
func _on_receive_update(state_dict: Dictionary, events: Array) -> void:
	_client_state = ClientState.from_dict(state_dict)
	state_updated.emit(_client_state, events)


@rpc("authority", "reliable")
func _on_receive_actions(actions: Array) -> void:
	# Reconstruct enum types from int
	var typed: Array = []
	for a in actions:
		var d: Dictionary = a.duplicate()
		d["type"] = d["type"] as Enums.ActionType
		typed.append(d)
	_current_actions = typed
	actions_received.emit(typed)


@rpc("authority", "reliable")
func _on_receive_choice(choice_data: Dictionary) -> void:
	choice_requested.emit(choice_data)


@rpc("authority", "reliable")
func _on_receive_game_started() -> void:
	game_started.emit()


@rpc("authority", "reliable")
func _on_receive_game_over(winner: int) -> void:
	game_over.emit(winner)

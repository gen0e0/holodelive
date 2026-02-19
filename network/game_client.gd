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
# Send to server
# =============================================================================

func send_action(action: Dictionary) -> void:
	var nm: Node = get_parent()
	if nm.is_host:
		# Host: call server directly (rpc_id to self doesn't trigger without call_local)
		nm.get_node("GameServer").request_action(action)
	else:
		# Guest: send via RPC to host's GameServer
		nm.get_node("GameServer").request_action.rpc_id(1, action)


func send_choice(choice_idx: int, value: int) -> void:
	var nm: Node = get_parent()
	if nm.is_host:
		nm.get_node("GameServer").request_choice(choice_idx, value)
	else:
		nm.get_node("GameServer").request_choice.rpc_id(1, choice_idx, value)


# =============================================================================
# RPC receive from server
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

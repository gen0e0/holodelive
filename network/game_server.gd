class_name GameServer
extends Node

var state: GameState
var controller: GameController
var registry: CardRegistry
var skill_registry: SkillRegistry
var _last_log_index: int = 0


func start_game() -> void:
	var loaded: Dictionary = CardLoader.load_all()
	registry = loaded["card_registry"]
	skill_registry = loaded["skill_registry"]
	state = GameSetup.setup_game(registry)
	controller = GameController.new(state, registry, skill_registry)
	_last_log_index = 0

	# Notify all clients that game started
	_broadcast_to_clients("_on_receive_game_started", [])

	_do_start_turn()


@rpc("any_peer", "reliable")
func request_action(action: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	# sender_id == 0 means local call (host)
	var player_index: int = _resolve_player(sender_id)

	if player_index < 0:
		push_warning("[GameServer] Unknown peer: %d" % sender_id)
		return

	if state.current_player != player_index:
		push_warning("[GameServer] Not player %d's turn" % player_index)
		return

	var available: Array = controller.get_available_actions()
	if not _is_valid_action(action, available):
		push_warning("[GameServer] Invalid action from player %d" % player_index)
		return

	var prev_turn: int = state.turn_number
	controller.apply_action(action)
	_flush_and_send()
	_advance(prev_turn)


@rpc("any_peer", "reliable")
func request_choice(choice_idx: int, value: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var player_index: int = _resolve_player(sender_id)

	if player_index < 0:
		push_warning("[GameServer] Unknown peer: %d" % sender_id)
		return

	# Validate that the choice is expected for this player
	var pc: PendingChoice = _get_active_pending_choice()
	if pc == null:
		push_warning("[GameServer] No pending choice")
		return

	if pc.target_player != player_index:
		push_warning("[GameServer] Choice not for player %d" % player_index)
		return

	if not pc.valid_targets.has(value):
		push_warning("[GameServer] Invalid choice value: %d" % value)
		return

	var prev_turn: int = state.turn_number
	controller.submit_choice(choice_idx, value)
	_flush_and_send()
	_advance(prev_turn)


# =============================================================================
# Internal
# =============================================================================

func _resolve_player(sender_id: int) -> int:
	if sender_id == 0:
		# Local call from host → player 0
		return 0
	var nm: Node = get_parent()
	return nm.get_player_index(sender_id)


func _do_start_turn(depth: int = 0) -> void:
	if depth > 10:
		return

	if controller.is_game_over():
		_flush_and_send()
		var winner: int = controller.get_winner()
		_broadcast_to_clients("_on_receive_game_over", [winner])
		return

	var live_happened: bool = controller.start_turn()
	_flush_and_send()

	if live_happened:
		if controller.is_game_over():
			var winner: int = controller.get_winner()
			_broadcast_to_clients("_on_receive_game_over", [winner])
			return
		_do_start_turn(depth + 1)
		return

	# Send available actions to current player
	_send_actions_to_current_player()


func _flush_and_send() -> void:
	var log_size: int = state.action_log.size()
	var new_actions: Array = []
	for i in range(_last_log_index, log_size):
		new_actions.append(state.action_log[i])
	_last_log_index = log_size

	var nm: Node = get_parent()
	for player in range(2):
		var events: Array = EventSerializer.serialize_events(new_actions, player, state, registry)
		var cs: ClientState = StateSerializer.serialize_for_player(state, player, registry)
		var state_dict: Dictionary = cs.to_dict()

		_send_to_player(player, "_on_receive_update", [state_dict, events])


func _send_actions_to_current_player() -> void:
	var actions: Array = controller.get_available_actions()
	# Serialize actions to plain dictionaries for RPC
	var serialized: Array = []
	for a in actions:
		var d: Dictionary = {}
		d["type"] = int(a["type"])
		if a.has("instance_id"):
			d["instance_id"] = a["instance_id"]
		if a.has("target"):
			d["target"] = a["target"]
		if a.has("skill_index"):
			d["skill_index"] = a["skill_index"]
		serialized.append(d)

	_send_to_player(state.current_player, "_on_receive_actions", [serialized])


func _advance(prev_turn: int) -> void:
	if controller.is_game_over():
		var winner: int = controller.get_winner()
		_broadcast_to_clients("_on_receive_game_over", [winner])
		return

	if controller.is_waiting_for_choice():
		var pc: PendingChoice = _get_active_pending_choice()
		if pc:
			var choice_data: Dictionary = _make_choice_data(pc)
			_send_to_player(pc.target_player, "_on_receive_choice", [choice_data])
		return

	if state.turn_number != prev_turn:
		_do_start_turn()
		return

	_send_actions_to_current_player()


func _is_valid_action(action: Dictionary, available: Array) -> bool:
	var atype: int = int(action.get("type", -1))
	for a in available:
		var match_type: bool = int(a["type"]) == atype
		if not match_type:
			continue

		if atype == Enums.ActionType.PASS:
			return true

		if a.has("instance_id") and action.get("instance_id", -1) != a["instance_id"]:
			continue

		if a.has("target") and action.get("target", "") != a["target"]:
			continue

		if a.has("skill_index") and action.get("skill_index", -1) != a["skill_index"]:
			continue

		return true

	return false


func _get_active_pending_choice() -> PendingChoice:
	for pc in state.pending_choices:
		if not pc.resolved:
			return pc
	return null


func _make_choice_data(pc: PendingChoice) -> Dictionary:
	var details: Array = []
	for target in pc.valid_targets:
		if target is int and target >= 0:
			details.append(StateSerializer._card_dict(target, state, registry))
		else:
			details.append({})

	return {
		"choice_index": state.pending_choices.find(pc),
		"target_player": pc.target_player,
		"choice_type": int(pc.choice_type),
		"valid_targets": pc.valid_targets,
		"valid_target_details": details,
	}


# =============================================================================
# RPC helpers
# =============================================================================

func _send_to_player(player: int, method: String, args: Array) -> void:
	var nm: Node = get_parent()
	var peer_id: int = nm.get_peer_id_for_player(player)
	if peer_id < 0:
		return

	var client: GameClient = nm.get_node("GameClient")
	if peer_id == 1:
		# Host: call directly on local GameClient
		client.callv(method, args)
	else:
		# Remote peer: send via RPC (explicit dispatch by arg count)
		match args.size():
			0: client.rpc_id(peer_id, method)
			1: client.rpc_id(peer_id, method, args[0])
			2: client.rpc_id(peer_id, method, args[0], args[1])
			3: client.rpc_id(peer_id, method, args[0], args[1], args[2])


func _broadcast_to_clients(method: String, args: Array) -> void:
	var nm: Node = get_parent()
	for pid in nm._peer_to_player:
		var player: int = nm._peer_to_player[pid]
		_send_to_player(player, method, args)

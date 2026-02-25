class_name GameServer
extends Node

## Server-authoritative game logic. Only exists on the host.
## All communication with clients goes through GameClient's RPC layer.

var state: GameState
var controller: GameController
var registry: CardRegistry
var skill_registry: SkillRegistry
var _last_log_index: int = 0
var _choice_timer: Timer = null
var _cpu_strategies: Dictionary = {}

const CPU_DELAY: float = 0.5


func start_game() -> void:
	var loaded: Dictionary = CardLoader.load_all()
	registry = loaded["card_registry"]
	skill_registry = loaded["skill_registry"]
	state = GameSetup.setup_game(registry)
	controller = GameController.new(state, registry, skill_registry)
	_last_log_index = 0

	_broadcast_to_clients("_on_receive_game_started", [])
	_do_start_turn()


## Register a player index as CPU-controlled with the given strategy.
## If strategy is null, defaults to RandomStrategy.
func set_cpu_player(player_index: int, strategy: CpuStrategy = null) -> void:
	if not _cpu_strategies.has(player_index):
		if strategy == null:
			strategy = RandomStrategy.new()
		_cpu_strategies[player_index] = strategy
		print("[GameServer] Player %d is now CPU-controlled" % player_index)


func _is_cpu_player(player_index: int) -> bool:
	return _cpu_strategies.has(player_index)


## Check if CPU needs to act right now (e.g. after disconnect handoff).
func check_cpu_needs_action() -> void:
	if controller.is_game_over():
		return

	if controller.is_waiting_for_choice():
		var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
		if pc and _is_cpu_player(pc.target_player):
			_stop_choice_timer()
			var choice_data: Dictionary = ChoiceHelper.make_choice_data(pc, state, registry)
			_schedule_cpu_choice(choice_data)
		return

	if _is_cpu_player(state.current_player):
		var actions: Array = controller.get_available_actions()
		_schedule_cpu_action(actions)


## Called by GameClient when a player submits an action.
func receive_action(action: Dictionary, player_index: int) -> void:
	if player_index < 0:
		push_warning("[GameServer] Unknown player index: %d" % player_index)
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


## Called by GameClient when a player submits a choice.
func receive_choice(choice_idx: int, value: int, player_index: int) -> void:
	if player_index < 0:
		push_warning("[GameServer] Unknown player index: %d" % player_index)
		return

	var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
	if pc == null:
		push_warning("[GameServer] No pending choice")
		return

	if pc.target_player != player_index:
		push_warning("[GameServer] Choice not for player %d" % player_index)
		return

	if not pc.valid_targets.has(value):
		push_warning("[GameServer] Invalid choice value: %d" % value)
		return

	_stop_choice_timer()

	var prev_turn: int = state.turn_number
	controller.submit_choice(choice_idx, value)
	_flush_and_send()
	_advance(prev_turn)


# =============================================================================
# Internal game flow
# =============================================================================

func _do_start_turn(depth: int = 0) -> void:
	if depth > 10:
		return

	if controller.is_game_over():
		_flush_and_send()
		_broadcast_to_clients("_on_receive_game_over", [controller.get_winner()])
		return

	var live_happened: bool = controller.start_turn()
	_flush_and_send()

	if live_happened:
		if controller.is_game_over():
			_broadcast_to_clients("_on_receive_game_over", [controller.get_winner()])
			return
		_do_start_turn(depth + 1)
		return

	_send_actions_to_current_player()


func _flush_and_send() -> void:
	var log_size: int = state.action_log.size()
	var new_actions: Array = []
	for i in range(_last_log_index, log_size):
		new_actions.append(state.action_log[i])
	_last_log_index = log_size

	for player in range(2):
		if _is_cpu_player(player):
			continue
		var events: Array = EventSerializer.serialize_events(new_actions, player, state, registry)
		var cs: ClientState = StateSerializer.serialize_for_player(state, player, registry)
		var state_dict: Dictionary = cs.to_dict()
		_send_to_player(player, "_on_receive_update", [state_dict, events])


func _send_actions_to_current_player() -> void:
	var actions: Array = controller.get_available_actions()

	if _is_cpu_player(state.current_player):
		_schedule_cpu_action(actions)
		return

	# パスしか選択肢がない場合は自動パス
	if _is_pass_only(actions):
		var prev_turn: int = state.turn_number
		controller.apply_action({"type": Enums.ActionType.PASS})
		_flush_and_send()
		_advance(prev_turn)
		return

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
		_broadcast_to_clients("_on_receive_game_over", [controller.get_winner()])
		return

	if controller.is_waiting_for_choice():
		var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
		if pc:
			var choice_data: Dictionary = ChoiceHelper.make_choice_data(pc, state, registry)
			if _is_cpu_player(pc.target_player):
				_schedule_cpu_choice(choice_data)
			else:
				_send_to_player(pc.target_player, "_on_receive_choice", [choice_data])
				_start_choice_timer(pc)
		return

	if state.turn_number != prev_turn:
		_do_start_turn()
		return

	_send_actions_to_current_player()


# =============================================================================
# CPU scheduling — delayed execution via Timer
# =============================================================================

func _schedule_cpu_action(actions: Array) -> void:
	var strategy: CpuStrategy = _cpu_strategies[state.current_player]
	var action: Dictionary = strategy.pick_action(actions, state, registry)
	if action.is_empty():
		return
	var player_index: int = state.current_player
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = CPU_DELAY
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		receive_action(action, player_index)
	)
	add_child(timer)
	timer.start()


func _schedule_cpu_choice(choice_data: Dictionary) -> void:
	var pc_for_strategy: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
	var strategy: CpuStrategy = _cpu_strategies[pc_for_strategy.target_player]
	var result: Dictionary = strategy.pick_choice(choice_data, state, registry)
	if result.is_empty():
		return
	var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
	if pc == null:
		return
	var player_index: int = pc.target_player
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = CPU_DELAY
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		receive_choice(result["choice_index"], result["value"], player_index)
	)
	add_child(timer)
	timer.start()


# =============================================================================
# Validation helpers
# =============================================================================

func _is_pass_only(actions: Array) -> bool:
	if actions.is_empty():
		return false
	for a in actions:
		if a.get("type") != Enums.ActionType.PASS:
			return false
	return true


func _is_valid_action(action: Dictionary, available: Array) -> bool:
	var atype: int = int(action.get("type", -1))
	for a in available:
		if int(a["type"]) != atype:
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


# =============================================================================
# Client communication — delegates to GameClient for RPC
# =============================================================================

func _send_to_player(player: int, method: String, args: Array) -> void:
	if _is_cpu_player(player):
		return
	var nm: Node = get_parent()
	var peer_id: int = nm.get_peer_id_for_player(player)
	if peer_id < 0:
		return

	# GameClient の _on_receive_* は call_local 付きなので、
	# rpc_id(1, ...) でもホスト自身のローカル実行が走る。
	var client: GameClient = nm.get_node("GameClient")
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


# =============================================================================
# Choice timer
# =============================================================================

func _start_choice_timer(pc: PendingChoice) -> void:
	_stop_choice_timer()
	if pc.timeout <= 0.0:
		return
	_choice_timer = Timer.new()
	_choice_timer.one_shot = true
	_choice_timer.wait_time = pc.timeout
	_choice_timer.timeout.connect(_on_choice_timeout)
	add_child(_choice_timer)
	_choice_timer.start()


func _stop_choice_timer() -> void:
	if _choice_timer != null:
		_choice_timer.stop()
		_choice_timer.queue_free()
		_choice_timer = null


func _on_choice_timeout() -> void:
	_stop_choice_timer()

	var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
	if pc == null or pc.valid_targets.is_empty():
		return

	var value: Variant = _pick_by_strategy(pc.timeout_strategy, pc.valid_targets)
	var choice_idx: int = state.pending_choices.find(pc)

	var prev_turn: int = state.turn_number
	controller.submit_choice(choice_idx, value)
	_flush_and_send()
	_advance(prev_turn)


func _pick_by_strategy(strategy: String, targets: Array) -> Variant:
	match strategy:
		"last":
			return targets[targets.size() - 1]
		"random":
			return targets[randi() % targets.size()]
		_:  # "first"
			return targets[0]

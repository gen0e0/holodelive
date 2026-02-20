class_name LocalGameSession
extends GameSession

var state: GameState
var controller: GameController
var registry: CardRegistry
var skill_registry: SkillRegistry
var _last_log_index: int = 0
var _client_state: ClientState

## CPU strategies keyed by player index (e.g. {1: RandomStrategy}).
var _cpu_strategies: Dictionary = {}
## The human player's index, used as the viewing perspective.
var human_player: int = 0


## Register a player index as CPU-controlled with the given strategy.
## If strategy is null, defaults to RandomStrategy.
func set_cpu_player(player_index: int, strategy: CpuStrategy = null) -> void:
	if strategy == null:
		strategy = RandomStrategy.new()
	_cpu_strategies[player_index] = strategy

const MAX_CPU_DEPTH: int = 500


func start_game() -> void:
	var loaded: Dictionary = CardLoader.load_all()
	registry = loaded["card_registry"]
	skill_registry = loaded["skill_registry"]
	state = GameSetup.setup_game(registry)
	controller = GameController.new(state, registry, skill_registry)
	_last_log_index = 0
	_client_state = null

	game_started.emit()
	_do_start_turn()


func send_action(action: Dictionary) -> void:
	var prev_turn: int = state.turn_number
	controller.apply_action(action)
	_flush_updates()
	_advance(prev_turn)


func send_choice(choice_idx: int, value: Variant) -> void:
	var prev_turn: int = state.turn_number
	controller.submit_choice(choice_idx, value)
	_flush_updates()
	_advance(prev_turn)


func get_client_state() -> ClientState:
	return _client_state


func get_available_actions() -> Array:
	return controller.get_available_actions()


func is_my_turn() -> bool:
	if controller.is_game_over() or controller.is_waiting_for_choice():
		return false
	if _is_cpu_player(state.current_player):
		return false
	return true


# =============================================================================
# CPU helpers
# =============================================================================

func _is_cpu_player(player_index: int) -> bool:
	return _cpu_strategies.has(player_index)


func _cpu_take_action(depth: int = 0) -> void:
	if depth > MAX_CPU_DEPTH:
		push_warning("[LocalGameSession] CPU depth limit reached")
		return
	var actions: Array = controller.get_available_actions()
	var strategy: CpuStrategy = _cpu_strategies[state.current_player]
	var action: Dictionary = strategy.pick_action(actions, state, registry)
	if action.is_empty():
		return
	var prev_turn: int = state.turn_number
	controller.apply_action(action)
	_flush_updates()
	_advance_cpu(prev_turn, depth)


func _cpu_take_choice(choice_data: Dictionary, depth: int = 0) -> void:
	if depth > MAX_CPU_DEPTH:
		push_warning("[LocalGameSession] CPU depth limit reached")
		return
	var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
	var strategy: CpuStrategy = _cpu_strategies[pc.target_player]
	var result: Dictionary = strategy.pick_choice(choice_data, state, registry)
	if result.is_empty():
		return
	var prev_turn: int = state.turn_number
	controller.submit_choice(result["choice_index"], result["value"])
	_flush_updates()
	_advance_cpu(prev_turn, depth)


# =============================================================================
# Internal
# =============================================================================

func _do_start_turn(depth: int = 0) -> void:
	if depth > 10:
		return

	if controller.is_game_over():
		_flush_updates()
		game_over.emit(controller.get_winner())
		return

	var live_happened: bool = controller.start_turn()
	_flush_updates()

	if live_happened:
		if controller.is_game_over():
			game_over.emit(controller.get_winner())
			return
		_do_start_turn(depth + 1)
		return

	_emit_actions()


func _flush_updates() -> void:
	var log_size: int = state.action_log.size()
	var new_actions: Array = []
	for i in range(_last_log_index, log_size):
		new_actions.append(state.action_log[i])
	_last_log_index = log_size

	var viewing_player: int = human_player
	var events: Array = EventSerializer.serialize_events(new_actions, viewing_player, state, registry)
	_client_state = StateSerializer.serialize_for_player(state, viewing_player, registry)
	state_updated.emit(_client_state, events)


func _emit_actions() -> void:
	if _is_cpu_player(state.current_player):
		_cpu_take_action()
		return
	var actions: Array = controller.get_available_actions()
	actions_received.emit(actions)


func _advance(prev_turn: int) -> void:
	if controller.is_game_over():
		game_over.emit(controller.get_winner())
		return

	if controller.is_waiting_for_choice():
		var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
		if pc:
			var choice_data: Dictionary = ChoiceHelper.make_choice_data(pc, state, registry)
			if _is_cpu_player(pc.target_player):
				_cpu_take_choice(choice_data)
			else:
				choice_requested.emit(choice_data)
		return

	if state.turn_number != prev_turn:
		_do_start_turn()
		return

	_emit_actions()


## Same as _advance but carries CPU depth counter to prevent infinite recursion.
func _advance_cpu(prev_turn: int, depth: int) -> void:
	if controller.is_game_over():
		game_over.emit(controller.get_winner())
		return

	if controller.is_waiting_for_choice():
		var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
		if pc:
			var choice_data: Dictionary = ChoiceHelper.make_choice_data(pc, state, registry)
			if _is_cpu_player(pc.target_player):
				_cpu_take_choice(choice_data, depth + 1)
			else:
				choice_requested.emit(choice_data)
		return

	if state.turn_number != prev_turn:
		_do_start_turn()
		return

	if _is_cpu_player(state.current_player):
		_cpu_take_action(depth + 1)
		return

	var actions: Array = controller.get_available_actions()
	actions_received.emit(actions)

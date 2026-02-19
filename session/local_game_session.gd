class_name LocalGameSession
extends GameSession

var state: GameState
var controller: GameController
var registry: CardRegistry
var skill_registry: SkillRegistry
var _last_log_index: int = 0
var _client_state: ClientState


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
	return not controller.is_game_over() and not controller.is_waiting_for_choice()


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

	var viewing_player: int = state.current_player
	var events: Array = EventSerializer.serialize_events(new_actions, viewing_player, state, registry)
	_client_state = StateSerializer.serialize_for_player(state, viewing_player, registry)
	state_updated.emit(_client_state, events)


func _emit_actions() -> void:
	var actions: Array = controller.get_available_actions()
	actions_received.emit(actions)


func _advance(prev_turn: int) -> void:
	if controller.is_game_over():
		game_over.emit(controller.get_winner())
		return

	if controller.is_waiting_for_choice():
		var pc: PendingChoice = _get_active_pending_choice()
		if pc:
			var choice_data: Dictionary = _make_choice_data(pc)
			choice_requested.emit(choice_data)
		return

	if state.turn_number != prev_turn:
		_do_start_turn()
		return

	_emit_actions()


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
			details.append(null)

	return {
		"choice_index": state.pending_choices.find(pc),
		"target_player": pc.target_player,
		"choice_type": pc.choice_type,
		"valid_targets": pc.valid_targets,
		"valid_target_details": details,
	}

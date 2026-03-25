class_name LocalGameSession
extends GameSession

var state: GameState
var controller: GameController
var registry: CardRegistry
var skill_registry: SkillRegistry
var _last_log_index: int = 0
var _client_state: ClientState
var _pending_interaction: Dictionary = {}  # {"type": "actions", "player": int, "data": ...}
var _defer_interactions: bool = false  # true の場合、actions を即発行せず保留

## PlayerController per player slot.
var _controllers: Array = [null, null]  # [PlayerController?, PlayerController?]
## ビューアーリスト: 各要素 = {player: int, callback: Callable, snapshots: Array}
var _viewers: Array = []
## Shared RNG for deterministic replay. If null, uses random seed.
var rng: RandomNumberGenerator
## ターン制限（0=無制限）。到達時に game_over(-1) を強制発火。
var max_turns: int = 0


## アニメーション付きUIが接続されている場合に呼ぶ。
## actions を即発行せずアニメーション完了後まで保留する。
func set_defer_interactions(enabled: bool) -> void:
	_defer_interactions = enabled


## ビューアーを登録する。player 視点で state_updated を callback に配信。
func add_viewer(player: int, callback: Callable) -> void:
	_viewers.append({"player": player, "callback": callback, "snapshots": []})


## ビューアーを解除する。
func remove_viewer(callback: Callable) -> void:
	for i in range(_viewers.size() - 1, -1, -1):
		if _viewers[i]["callback"] == callback:
			_viewers.remove_at(i)


## プレイヤーの操作コントローラを登録する。
func set_player_controller(player: int, pc: PlayerController) -> void:
	_controllers[player] = pc
	pc.action_decided.connect(func(action: Dictionary) -> void:
		_on_controller_action(player, action))
	pc.choice_decided.connect(func(idx: int, value: Variant) -> void:
		_on_controller_choice(idx, value))


## 後方互換: CPU プレイヤーを登録する。内部で CpuPlayerController を生成する。
func set_cpu_player(player_index: int, strategy: CpuStrategy = null) -> void:
	if strategy == null:
		var rng_to_use: RandomNumberGenerator = rng if rng else RandomNumberGenerator.new()
		strategy = RandomStrategy.new(rng_to_use)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var cpu := CpuPlayerController.new(strategy,
		func() -> GameState: return state,
		func() -> CardRegistry: return registry,
		tree, 0.0)
	set_player_controller(player_index, cpu)


func start_game() -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var loaded: Dictionary = CardLoader.load_all()
	registry = loaded["card_registry"]
	skill_registry = loaded["skill_registry"]
	state = GameSetup.setup_game(registry, rng)
	controller = GameController.new(state, registry, skill_registry)
	controller.on_action_logged = _on_action_logged
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
	# 最初のビューアーの視点で判定
	var vp: int = _viewers[0]["player"] if not _viewers.is_empty() else 0
	return state.current_player == vp


# =============================================================================
# PlayerController callbacks
# =============================================================================

func _on_controller_action(player: int, action: Dictionary) -> void:
	if state.current_player != player:
		return  # stale response
	send_action(action)


func _on_controller_choice(choice_idx: int, value: Variant) -> void:
	send_choice(choice_idx, value)


# =============================================================================
# Helpers
# =============================================================================

func _is_pass_only(actions: Array) -> bool:
	if actions.is_empty():
		return false
	for a in actions:
		if a.get("type") != Enums.ActionType.PASS:
			return false
	return true


# =============================================================================
# Internal
# =============================================================================

func _do_start_turn(depth: int = 0) -> void:
	if depth > 10:
		return

	# ターン制限チェック
	if max_turns > 0 and state.turn_number > max_turns:
		_flush_updates()
		game_over.emit(-1)
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

	_request_actions()


func _on_action_logged() -> void:
	for viewer in _viewers:
		viewer["snapshots"].append(
			StateSerializer.serialize_for_player(state, viewer["player"], registry))


func _flush_updates() -> void:
	var log_size: int = state.action_log.size()
	var new_actions: Array = []
	for i in range(_last_log_index, log_size):
		new_actions.append(state.action_log[i])
	_last_log_index = log_size

	# SESSION ログ（ビューアーに依存しない、1回だけ出力）
	for ga in new_actions:
		var log_data: Dictionary = {"player": ga.player}
		if ga.type == Enums.ActionType.PLAY_CARD:
			var iid: int = ga.params.get("instance_id", -1)
			var inst: CardInstance = state.instances.get(iid)
			if inst:
				var card_def: CardDef = registry.get_card(inst.card_id)
				log_data["card_id"] = inst.card_id
				log_data["name"] = card_def.nickname if card_def else "?"
				log_data["target"] = ga.params.get("target", "?")
		GameLog.log_event("SESSION", Enums.ActionType.keys()[ga.type], log_data)

	# 各ビューアーに視点別のイベントを配信
	for viewer in _viewers:
		var p: int = viewer["player"]
		var events: Array = EventSerializer.serialize_events(new_actions, p, state, registry)
		var snapshots: Array = viewer["snapshots"]
		assert(events.size() == snapshots.size(),
			"snapshot count mismatch: %d events vs %d snapshots" %
			[events.size(), snapshots.size()])

		var event_entries: Array = []
		for i in range(events.size()):
			event_entries.append({
				"event": events[i],
				"snapshot": snapshots[i],
			})
		snapshots.clear()

		var cs_final: ClientState
		if not event_entries.is_empty():
			cs_final = event_entries.back().get("snapshot")
		else:
			cs_final = StateSerializer.serialize_for_player(state, p, registry)

		viewer["callback"].call(cs_final, event_entries)

	# _client_state は最初のビューアー視点（get_client_state 用）
	if not _viewers.is_empty():
		_client_state = StateSerializer.serialize_for_player(
			state, _viewers[0]["player"], registry)
	else:
		_client_state = null


func _request_actions() -> void:
	var actions: Array = controller.get_available_actions()
	if _is_pass_only(actions):
		send_action({"type": Enums.ActionType.PASS})
		return
	var player: int = state.current_player
	if _controllers[player] != null:
		if _defer_interactions:
			_pending_interaction = {"type": "actions", "player": player, "data": actions}
		else:
			_controllers[player].request_action(actions)
	else:
		# レガシーフォールバック: コントローラ未登録時はシグナルで通知
		if _defer_interactions:
			_pending_interaction = {"type": "actions", "data": actions}
		else:
			actions_received.emit(actions)


func _request_choice(player: int, choice_data: Dictionary) -> void:
	# choice は常に即座に発行（現行動作維持）
	if _controllers[player] != null:
		_controllers[player].request_choice(choice_data)
	else:
		# レガシーフォールバック
		choice_requested.emit(choice_data)


func flush_pending_interaction() -> void:
	var pending: Dictionary = _pending_interaction
	_pending_interaction = {}
	if pending.is_empty():
		return
	if pending.get("type", "") == "actions":
		var player: int = pending.get("player", state.current_player)
		if _controllers[player] != null:
			_controllers[player].request_action(pending["data"])
		else:
			actions_received.emit(pending["data"])


func _advance(prev_turn: int) -> void:
	if controller.is_game_over():
		game_over.emit(controller.get_winner())
		return

	if controller.is_waiting_for_choice():
		for pc in state.pending_choices:
			if not pc.resolved and not pc.dispatched:
				pc.dispatched = true
				var choice_data: Dictionary = ChoiceHelper.make_choice_data(pc, state, registry)
				_request_choice(pc.target_player, choice_data)
		return

	if state.turn_number != prev_turn:
		_do_start_turn()
		return

	_request_actions()

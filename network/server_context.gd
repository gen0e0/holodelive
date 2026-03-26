class_name ServerContext
extends Node

## ゲームの権威（サーバー側）。GameState と GameController を所有し、
## ゲームループを駆動する。状態更新は GameBridge 経由で全クライアントに配信。

var state: GameState
var controller: GameController
var registry: CardRegistry
var skill_registry: SkillRegistry
var rng: RandomNumberGenerator
var max_turns: int = 0

var _controllers: Array = [null, null]  # PlayerController per player
var _bridge: GameBridge
var _last_log_index: int = 0
var _viewers: Array = []  # [{player: int, snapshots: Array}]
var _pending_interaction: Dictionary = {}
var _defer_interactions: bool = false


func setup(bridge: GameBridge, p_rng: RandomNumberGenerator = null) -> void:
	_bridge = bridge
	bridge._server_context = self
	rng = p_rng if p_rng else RandomNumberGenerator.new()
	if p_rng == null:
		rng.randomize()


func set_defer_interactions(enabled: bool) -> void:
	_defer_interactions = enabled


## ビューアーを登録する。player 視点でスナップショットを蓄積。
func add_viewer(player: int) -> void:
	_viewers.append({"player": player, "snapshots": []})


## ビューアーを解除する。
func remove_viewer(player: int) -> void:
	for i in range(_viewers.size() - 1, -1, -1):
		if _viewers[i]["player"] == player:
			_viewers.remove_at(i)


## プレイヤーの操作コントローラを登録する。
func set_player_controller(player: int, pc: PlayerController) -> void:
	_controllers[player] = pc
	pc.action_decided.connect(func(action: Dictionary) -> void:
		_on_controller_action(player, action))
	pc.choice_decided.connect(func(idx: int, value: Variant) -> void:
		_on_controller_choice(idx, value))


func start_game() -> void:
	var loaded: Dictionary = CardLoader.load_all()
	registry = loaded["card_registry"]
	skill_registry = loaded["skill_registry"]
	state = GameSetup.setup_game(registry, rng)
	controller = GameController.new(state, registry, skill_registry)
	controller.on_action_logged = _on_action_logged
	_last_log_index = 0

	_bridge.broadcast_game_started()
	_do_start_turn()


## 外部からアクションを受信する（GameBridge 経由）。
func receive_action(action: Dictionary, player: int) -> void:
	if state.current_player != player:
		return
	var available: Array = controller.get_available_actions()
	if not _is_valid_action(action, available):
		push_warning("[ServerContext] Invalid action from player %d" % player)
		return
	_apply_action(action)


## 外部からチョイスを受信する（GameBridge 経由）。
func receive_choice(choice_idx: int, value: Variant, player: int) -> void:
	if not controller.is_waiting_for_choice():
		return
	var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(state.pending_choices)
	if pc == null:
		return
	if pc.target_player != player:
		push_warning("[ServerContext] Choice not for player %d" % player)
		return
	if value is Array:
		for v in value:
			if not pc.valid_targets.has(v):
				push_warning("[ServerContext] Invalid choice value: %s" % str(v))
				return
	elif not pc.valid_targets.has(value):
		push_warning("[ServerContext] Invalid choice value: %s" % str(value))
		return
	_apply_choice(choice_idx, value)


# =============================================================================
# PlayerController callbacks
# =============================================================================

func _on_controller_action(player: int, action: Dictionary) -> void:
	if state.current_player != player:
		return
	_apply_action(action)


func _on_controller_choice(choice_idx: int, value: Variant) -> void:
	_apply_choice(choice_idx, value)


# =============================================================================
# Internal game loop
# =============================================================================

func _apply_action(action: Dictionary) -> void:
	var prev_turn: int = state.turn_number
	controller.apply_action(action)
	_flush_and_send()
	_advance(prev_turn)


func _apply_choice(choice_idx: int, value: Variant) -> void:
	var prev_turn: int = state.turn_number
	controller.submit_choice(choice_idx, value)
	_flush_and_send()
	_advance(prev_turn)


func _do_start_turn(depth: int = 0) -> void:
	if depth > 10:
		return

	if max_turns > 0 and state.turn_number > max_turns:
		_flush_and_send()
		_bridge.broadcast_game_over(-1)
		return

	if controller.is_game_over():
		_flush_and_send()
		_bridge.broadcast_game_over(controller.get_winner())
		return

	var live_happened: bool = controller.start_turn()
	_flush_and_send()

	if live_happened:
		if controller.is_game_over():
			_bridge.broadcast_game_over(controller.get_winner())
			return
		_do_start_turn(depth + 1)
		return

	_request_actions()


func _advance(prev_turn: int) -> void:
	if controller.is_game_over():
		_bridge.broadcast_game_over(controller.get_winner())
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


func _request_actions() -> void:
	var actions: Array = controller.get_available_actions()
	if _is_pass_only(actions):
		_apply_action({"type": Enums.ActionType.PASS})
		return
	var player: int = state.current_player
	if _controllers[player] != null:
		if _defer_interactions:
			_pending_interaction = {"type": "actions", "player": player, "data": actions}
		else:
			_controllers[player].request_action(actions)
	else:
		# PlayerController 未登録（ネットワーク経由で GameBridge から届く想定）
		_bridge.send_actions_to(player, actions)


func _request_choice(player: int, choice_data: Dictionary) -> void:
	# RANDOM_RESULT はプレイヤー入力不要 → サーバー側で自動解決
	if choice_data.get("choice_type", -1) == Enums.ChoiceType.RANDOM_RESULT:
		var targets: Array = choice_data.get("valid_targets", [])
		if not targets.is_empty():
			var value: Variant = targets[rng.randi() % targets.size()]
			_apply_choice(choice_data.get("choice_index", 0), value)
		return
	# 常に Bridge 経由で通知（UI 表示のため）
	_bridge.send_choice_to(player, choice_data)
	# コントローラがあれば自動応答も行う（CPU プレイヤー）
	if _controllers[player] != null:
		_controllers[player].request_choice(choice_data)


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
			_bridge.send_actions_to(player, pending["data"])


# =============================================================================
# State serialization & distribution
# =============================================================================

func _on_action_logged() -> void:
	for viewer in _viewers:
		viewer["snapshots"].append(
			StateSerializer.serialize_for_player(state, viewer["player"], registry))


func _flush_and_send() -> void:
	var log_size: int = state.action_log.size()
	var new_actions: Array = []
	for i in range(_last_log_index, log_size):
		new_actions.append(state.action_log[i])
	_last_log_index = log_size

	# SESSION ログ（1回だけ）
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

		# GameBridge 経由で配信（ClientState をそのまま渡す。ネットワーク時は Bridge が dict 変換）
		_bridge.send_state_to(p, cs_final, event_entries)


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

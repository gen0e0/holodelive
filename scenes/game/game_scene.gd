extends Control

## ネットワーク対戦シーン。GameRoom を使用してホスト/ゲストの両方に対応。
## LobbyScene から遷移され、NetworkManager が接続済みであることを前提とする。

const _GameRoomScene: PackedScene = preload("res://scenes/game/game_room.tscn")

var _game_room: GameRoom
var _my_player: int = -1

# --- UI nodes ---
var _state_display: RichTextLabel
var _log_display: RichTextLabel
var _input_line: LineEdit
var _btn_send: Button
var _player_label: Label

# --- Internal state ---
var _current_actions: Array = []
var _waiting_choice: bool = false
var _choice_data: Dictionary = {}
var _client_state: ClientState = null


func _ready() -> void:
	_build_ui()

	var nm: Node = get_node("/root/NetworkManager")

	# GameRoom インスタンス化
	_game_room = _GameRoomScene.instantiate()
	add_child(_game_room)

	if nm.is_host:
		_my_player = 0
		_player_label.text = "You are Player 0 (Host)"
		_game_room.setup_host()

		# 両プレイヤーのビューアーを登録
		_game_room.server_context.add_viewer(0)
		_game_room.server_context.add_viewer(1)

		# 切断ハンドラ
		nm.player_disconnected.connect(_on_player_disconnected)
	else:
		_my_player = 1
		_player_label.text = "You are Player 1 (Guest)"
		_game_room.setup_guest()

	# Bridge シグナル接続
	_game_room.bridge.state_received.connect(_on_state_received)
	_game_room.bridge.actions_received.connect(_on_actions_received)
	_game_room.bridge.choice_requested.connect(_on_choice_requested)
	_game_room.bridge.game_started_received.connect(_on_game_started)
	_game_room.bridge.game_over_received.connect(_on_game_over)

	# Host starts the game after a short delay to ensure guest scene is ready
	if nm.is_host:
		await get_tree().create_timer(1.0).timeout
		_game_room.server_context.start_game()


# =============================================================================
# ネットワーク切断
# =============================================================================

func _on_player_disconnected(peer_id: int) -> void:
	if not _game_room or not _game_room.server_context:
		return
	var nm: Node = get_node("/root/NetworkManager")
	var player_index: int = nm.get_player_index(peer_id)
	if player_index < 0:
		return
	_log("[color=yellow]Player %d disconnected — handing to CPU[/color]" % player_index)

	var ctx: ServerContext = _game_room.server_context
	var get_state: Callable = func() -> GameState: return ctx.state
	var get_registry: Callable = func() -> CardRegistry: return ctx.registry
	var cpu := CpuPlayerController.new(
		RandomStrategy.new(), get_state, get_registry, get_tree(), 0.5)
	ctx.set_player_controller(player_index, cpu)

	# CPU が今すぐ行動する必要があるかチェック
	if not ctx.controller.is_game_over():
		if ctx.controller.is_waiting_for_choice():
			var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(ctx.state.pending_choices)
			if pc and pc.target_player == player_index:
				var choice_data: Dictionary = ChoiceHelper.make_choice_data(pc, ctx.state, ctx.registry)
				cpu.request_choice(choice_data)
		elif ctx.state.current_player == player_index:
			var actions: Array = ctx.controller.get_available_actions()
			cpu.request_action(actions)


# =============================================================================
# Bridge シグナルハンドラ
# =============================================================================

func _on_game_started() -> void:
	_log("[color=yellow]--- Game Started ---[/color]")


func _on_state_received(player: int, client_state_or_dict: Variant, events: Array) -> void:
	if player != _my_player:
		return
	# ネットワーク（ゲスト）: Dictionary → ClientState 復元
	# ローカル/ホスト: ClientState そのまま
	if client_state_or_dict is Dictionary:
		_client_state = ClientState.from_dict(client_state_or_dict)
	else:
		_client_state = client_state_or_dict as ClientState
	_update_state_display(_client_state)
	for event in events:
		# events はネットワーク経由では flat な dict 配列
		var ev: Dictionary = event if event is Dictionary else event.get("event", {})
		var text: String = DisplayHelper.format_event(ev, _client_state)
		if not text.is_empty():
			_log(text)


func _on_actions_received(player: int, actions: Array) -> void:
	if player != _my_player:
		return
	_current_actions = actions
	_waiting_choice = false
	_btn_send.disabled = false

	var phase_name: String = DisplayHelper.get_phase_name(_client_state.phase) if _client_state else "?"
	_log("[color=green]Available actions (%s):[/color]" % phase_name)
	for i in range(_current_actions.size()):
		_log("  %d. %s" % [i + 1, DisplayHelper.format_action(_current_actions[i], _client_state)])

	_input_line.call_deferred("grab_focus")


func _on_choice_requested(player: int, choice_data_arg: Dictionary) -> void:
	if player != _my_player:
		return
	_waiting_choice = true
	_choice_data = choice_data_arg
	_btn_send.disabled = false

	var target_player: int = choice_data_arg.get("target_player", 0)
	var timeout: float = choice_data_arg.get("timeout", 0.0)
	if timeout > 0.0:
		_log("[color=green]Choose (for P%d) [timeout: %.0fs]:[/color]" % [target_player, timeout])
	else:
		_log("[color=green]Choose (for P%d):[/color]" % target_player)

	var valid_targets: Array = choice_data_arg.get("valid_targets", [])
	var details: Array = choice_data_arg.get("valid_target_details", [])
	for i in range(valid_targets.size()):
		var target: Variant = valid_targets[i]
		if target is int and target == -1:
			_log("  %d. Pass (decline)" % [i + 1])
		elif i < details.size() and details[i] != null:
			var d: Dictionary = details[i]
			if d.is_empty():
				_log("  %d. %s" % [i + 1, str(target)])
			else:
				_log("  %d. %s" % [i + 1, DisplayHelper.format_card_dict(d)])
		else:
			_log("  %d. %s" % [i + 1, str(target)])

	_input_line.call_deferred("grab_focus")


func _on_game_over(winner: int) -> void:
	_log("")
	_log("[color=yellow]========================================[/color]")
	if winner >= 0:
		_log("[color=yellow]  GAME OVER — Player %d Wins!  [/color]" % winner)
	else:
		_log("[color=yellow]  GAME OVER — Draw  [/color]")
	if _client_state:
		_log("[color=yellow]  Rounds: P0=%d  P1=%d[/color]" % [_client_state.round_wins[0], _client_state.round_wins[1]])
	_log("[color=yellow]========================================[/color]")
	_btn_send.disabled = true


# =============================================================================
# Input handlers
# =============================================================================

func _on_send_pressed() -> void:
	var text: String = _input_line.text.strip_edges()
	_input_line.clear()
	if text.is_empty():
		text = "1"

	if not text.is_valid_int():
		_log("[color=red]Invalid input: enter a number.[/color]")
		return

	var num: int = text.to_int()

	if _waiting_choice:
		_handle_choice_input(num)
	else:
		_handle_action_input(num)


func _on_text_submitted(_text: String) -> void:
	_on_send_pressed()


# =============================================================================
# Action processing
# =============================================================================

func _handle_action_input(num: int) -> void:
	if num < 1 or num > _current_actions.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % _current_actions.size())
		return

	var action: Dictionary = _current_actions[num - 1]
	_log("> %d" % num)
	_btn_send.disabled = true
	_game_room.bridge.send_action(action, _my_player)


func _handle_choice_input(num: int) -> void:
	var valid_targets: Array = _choice_data.get("valid_targets", [])
	var choice_index: int = _choice_data.get("choice_index", 0)

	if num < 1 or num > valid_targets.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % valid_targets.size())
		return

	var chosen_value: Variant = valid_targets[num - 1]
	_log("> %d" % num)
	_waiting_choice = false
	_btn_send.disabled = true
	_game_room.bridge.send_choice(choice_index, chosen_value, _my_player)


# =============================================================================
# Display
# =============================================================================

func _update_state_display(cs: ClientState) -> void:
	if cs == null:
		_state_display.text = ""
		return

	var phase_name: String = DisplayHelper.get_phase_name(cs.phase)

	var lines: Array[String] = []
	lines.append("[color=cyan]=== Round %d | Turn %d | P%d | Phase: %s ===[/color]" % [
		cs.round_number, cs.turn_number, cs.current_player, phase_name
	])
	lines.append("Wins: P0=%d P1=%d | Deck: %d | Home: %d | Removed: %d" % [
		cs.round_wins[0], cs.round_wins[1],
		cs.deck_count, cs.home.size(), cs.removed.size()
	])
	lines.append("My Player: P%d" % cs.my_player)
	lines.append("")

	for p in range(2):
		var color: String = "white" if p != cs.current_player else "green"
		var me_tag: String = " (me)" if p == cs.my_player else ""
		lines.append("[color=%s]--- Player %d%s ---[/color]" % [color, p, me_tag])

		# Hand
		if p == cs.my_player:
			var hand_str: String = ""
			if cs.my_hand.is_empty():
				hand_str = "(empty)"
			else:
				var parts: Array[String] = []
				for d in cs.my_hand:
					parts.append("[%s]" % DisplayHelper.format_card_dict(d))
				hand_str = " ".join(parts)
			lines.append("  Hand: %s" % hand_str)
		else:
			lines.append("  Hand: (%d cards)" % cs.opponent_hand_count)

		# Stage
		var stage_parts: Array[String] = []
		var stage_cards: Array = cs.stages[p]
		for d in stage_cards:
			var dict: Dictionary = d
			if dict.get("hidden", false):
				stage_parts.append("[face down]")
			else:
				stage_parts.append("[%s]" % DisplayHelper.format_card_dict(dict))
		var empty_count: int = 3 - stage_cards.size()
		for _i in range(empty_count):
			stage_parts.append("[empty]")
		lines.append("  Stage: %s" % " ".join(stage_parts))

		# Backstage
		var bs: Variant = cs.backstages[p]
		if bs == null:
			lines.append("  Backstage: empty")
		else:
			var bs_dict: Dictionary = bs
			if bs_dict.get("hidden", false):
				lines.append("  Backstage: (face down)")
			else:
				lines.append("  Backstage: %s" % DisplayHelper.format_card_dict(bs_dict))

		# Rank
		var g_stage_cards: Array = cs.stages[p]
		lines.append("  Rank: %s" % DisplayHelper.format_stage_rank(g_stage_cards))

		# Live ready
		var live_str: String = "Yes (turn %d)" % cs.live_ready_turn[p] if cs.live_ready[p] else "No"
		lines.append("  Live Ready: %s" % live_str)
		lines.append("")

	_state_display.clear()
	_state_display.append_text("\n".join(lines))


# =============================================================================
# UI
# =============================================================================

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var hsplit := HSplitContainer.new()
	hsplit.split_offset = 200
	margin.add_child(hsplit)

	# --- Left pane ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 180
	hsplit.add_child(left)

	var title := Label.new()
	title.text = "Network Game"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)

	left.add_child(HSeparator.new())

	_player_label = Label.new()
	_player_label.text = ""
	left.add_child(_player_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	# --- Right pane ---
	var vsplit := VSplitContainer.new()
	vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(vsplit)

	# Top: State display
	var state_panel := PanelContainer.new()
	state_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	state_panel.size_flags_stretch_ratio = 1.5
	vsplit.add_child(state_panel)

	_state_display = RichTextLabel.new()
	_state_display.bbcode_enabled = true
	_state_display.scroll_following = false
	_state_display.selection_enabled = true
	_state_display.focus_mode = Control.FOCUS_NONE
	state_panel.add_child(_state_display)

	# Bottom: Log + input
	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsplit.add_child(bottom)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_child(log_panel)

	_log_display = RichTextLabel.new()
	_log_display.bbcode_enabled = true
	_log_display.scroll_following = true
	_log_display.selection_enabled = true
	_log_display.focus_mode = Control.FOCUS_NONE
	log_panel.add_child(_log_display)

	var input_row := HBoxContainer.new()
	bottom.add_child(input_row)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Enter number..."
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.text_submitted.connect(_on_text_submitted)
	_input_line.focus_mode = Control.FOCUS_ALL
	input_row.add_child(_input_line)

	_btn_send = Button.new()
	_btn_send.text = "Send"
	_btn_send.disabled = true
	_btn_send.pressed.connect(_on_send_pressed)
	input_row.add_child(_btn_send)


# =============================================================================
# Log
# =============================================================================

func _log(msg: String) -> void:
	_log_display.append_text(msg + "\n")

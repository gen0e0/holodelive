extends Control

# --- セッション ---
var session: LocalGameSession

# --- UI ノード ---
var _btn_init: Button
var _btn_start: Button
var _state_display: RichTextLabel
var _log_display: RichTextLabel
var _input_line: LineEdit
var _btn_send: Button
var _cpu_toggle: CheckButton
var _cpu_speed_input: LineEdit
var _gui_toggle: CheckButton

# --- GUI ペイン ---
var _vsplit: VSplitContainer
var _state_panel: PanelContainer
var _gui_container: Control
var _game_screen: GameScreen

# --- 内部状態 ---
var _current_actions: Array = []
var _waiting_choice: bool = false
var _choice_data: Dictionary = {}
var _auto_epoch: int = 0


func _ready() -> void:
	_build_ui()


# =============================================================================
# UI 構築
# =============================================================================

func _build_ui() -> void:
	# ルートを full_rect にする
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

	# --- 左ペイン: メニュー ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 180
	hsplit.add_child(left)

	var title := Label.new()
	title.text = "Debug Menu"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)

	left.add_child(HSeparator.new())

	_btn_init = Button.new()
	_btn_init.text = "Init Game"
	_btn_init.pressed.connect(_on_init_pressed)
	left.add_child(_btn_init)

	_btn_start = Button.new()
	_btn_start.text = "Start Game"
	_btn_start.disabled = true
	_btn_start.pressed.connect(_on_start_pressed)
	left.add_child(_btn_start)

	# --- CPU Auto-Play ---
	left.add_child(HSeparator.new())

	_cpu_toggle = CheckButton.new()
	_cpu_toggle.text = "CPU Auto-Play"
	_cpu_toggle.button_pressed = false
	left.add_child(_cpu_toggle)

	var speed_row := HBoxContainer.new()
	left.add_child(speed_row)

	var speed_label := Label.new()
	speed_label.text = "Speed (s):"
	speed_row.add_child(speed_label)

	_cpu_speed_input = LineEdit.new()
	_cpu_speed_input.text = "5"
	_cpu_speed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cpu_speed_input.custom_minimum_size.x = 50
	speed_row.add_child(_cpu_speed_input)

	# --- GUI Mode Toggle ---
	left.add_child(HSeparator.new())

	_gui_toggle = CheckButton.new()
	_gui_toggle.text = "GUI Mode"
	_gui_toggle.button_pressed = false
	_gui_toggle.toggled.connect(_on_gui_toggled)
	left.add_child(_gui_toggle)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	# --- 右ペイン ---
	_vsplit = VSplitContainer.new()
	_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(_vsplit)

	# 上: 状態コンソール (テキスト)
	_state_panel = PanelContainer.new()
	_state_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_state_panel.size_flags_stretch_ratio = 1.5
	_vsplit.add_child(_state_panel)

	_state_display = RichTextLabel.new()
	_state_display.bbcode_enabled = true
	_state_display.scroll_following = false
	_state_display.selection_enabled = true
	_state_display.focus_mode = Control.FOCUS_NONE
	_state_panel.add_child(_state_display)

	# 上: GUI コンテナ（初期非表示、state_panel と排他）
	_gui_container = Control.new()
	_gui_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gui_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gui_container.visible = false
	_vsplit.add_child(_gui_container)

	# 下: ログ + 入力（常に表示）
	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vsplit.add_child(bottom)

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
# ボタンハンドラ
# =============================================================================

func _on_init_pressed() -> void:
	session = LocalGameSession.new()
	session.human_player = 0
	session.state_updated.connect(_on_state_updated)
	session.actions_received.connect(_on_actions_received)
	session.choice_requested.connect(_on_choice_requested)
	session.game_started.connect(_on_game_started)
	session.game_over.connect(_on_game_over)

	_current_actions = []
	_waiting_choice = false
	_choice_data = {}
	_auto_epoch += 1

	_log_display.clear()
	_log("[color=yellow]--- Session Created ---[/color]")
	_btn_start.disabled = false
	_btn_send.disabled = true
	_state_display.text = ""

	# GUI モードが有効ならセッションを接続
	if _game_screen != null:
		_game_screen.disconnect_session()
		if _gui_toggle.button_pressed:
			_game_screen.connect_session(session)


func _on_start_pressed() -> void:
	_btn_start.disabled = true
	_btn_init.disabled = true
	session.start_game()


func _on_send_pressed() -> void:
	var text := _input_line.text.strip_edges()
	_input_line.clear()
	if text.is_empty():
		text = "1"

	if not text.is_valid_int():
		_log("[color=red]Invalid input: enter a number.[/color]")
		return

	var num := text.to_int()

	# 手動入力時はエポックを進めて pending タイマーを無効化
	_auto_epoch += 1

	if _waiting_choice:
		_handle_choice_input(num)
	else:
		_handle_action_input(num)


func _on_text_submitted(_text: String) -> void:
	_on_send_pressed()


# =============================================================================
# セッションシグナルハンドラ
# =============================================================================

func _on_game_started() -> void:
	_log("[color=yellow]--- Game Started ---[/color]")


func _on_state_updated(client_state: ClientState, events: Array) -> void:
	_update_state_display(client_state)
	for event in events:
		var cs: ClientState = session.get_client_state()
		var text: String = DisplayHelper.format_event(event, cs)
		if not text.is_empty():
			_log(text)


func _on_actions_received(actions: Array) -> void:
	_auto_epoch += 1
	_current_actions = actions
	_waiting_choice = false
	_btn_send.disabled = false

	var cs: ClientState = session.get_client_state()
	var phase_name: String = DisplayHelper.get_phase_name(cs.phase) if cs else "?"
	_log("[color=green]Available actions (%s):[/color]" % phase_name)
	for i in range(_current_actions.size()):
		_log("  %d. %s" % [i + 1, DisplayHelper.format_action(_current_actions[i], cs)])

	var player: int = cs.current_player if cs else 0
	if _should_auto_respond_for_player(player):
		var delay: float = _get_cpu_speed() if _cpu_toggle.button_pressed else 0.0
		_schedule_auto_action(delay, _auto_epoch)
	else:
		_input_line.call_deferred("grab_focus")


func _on_choice_requested(choice_data_arg: Dictionary) -> void:
	_auto_epoch += 1
	_waiting_choice = true
	_choice_data = choice_data_arg
	_btn_send.disabled = false

	var target_player: int = choice_data_arg.get("target_player", 0)
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

	if _should_auto_respond_for_player(target_player):
		var delay: float = _get_cpu_speed() if _cpu_toggle.button_pressed else 0.0
		_schedule_auto_choice(delay, _auto_epoch)
	else:
		_input_line.call_deferred("grab_focus")


func _on_game_over(winner: int) -> void:
	_auto_epoch += 1
	var cs: ClientState = session.get_client_state()
	_log("")
	_log("[color=yellow]========================================[/color]")
	_log("[color=yellow]  GAME OVER — Player %d Wins!  [/color]" % winner)
	if cs:
		_log("[color=yellow]  Rounds: P0=%d  P1=%d[/color]" % [cs.round_wins[0], cs.round_wins[1]])
	_log("[color=yellow]========================================[/color]")
	_btn_send.disabled = true
	_btn_init.disabled = false


# =============================================================================
# GUI モード切替
# =============================================================================

func _on_gui_toggled(enabled: bool) -> void:
	_state_panel.visible = not enabled
	_gui_container.visible = enabled
	if enabled:
		if _game_screen == null:
			var scene: PackedScene = preload("res://scenes/gui/game_screen.tscn")
			_game_screen = scene.instantiate()
			_gui_container.add_child(_game_screen)
		if session != null:
			_game_screen.connect_session(session)
	else:
		if _game_screen != null and session != null:
			_game_screen.disconnect_session()


# =============================================================================
# CPU 自動応答
# =============================================================================

func _should_auto_respond_for_player(player: int) -> bool:
	if _cpu_toggle.button_pressed:
		return true
	# トグルOFF: P1 のみ自動応答
	return player == 1


func _get_cpu_speed() -> float:
	var text: String = _cpu_speed_input.text.strip_edges()
	if text.is_valid_float():
		var val: float = text.to_float()
		if val >= 0.0:
			return val
	return 5.0


func _schedule_auto_action(delay: float, epoch: int) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	else:
		await get_tree().process_frame
	if epoch != _auto_epoch:
		return
	if _current_actions.is_empty():
		return
	var idx: int = randi() % _current_actions.size()
	var action: Dictionary = _current_actions[idx]
	_log("[color=gray](CPU) > %d[/color]" % [idx + 1])
	session.send_action(action)


func _schedule_auto_choice(delay: float, epoch: int) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	else:
		await get_tree().process_frame
	if epoch != _auto_epoch:
		return
	var valid_targets: Array = _choice_data.get("valid_targets", [])
	if valid_targets.is_empty():
		return
	var idx: int = randi() % valid_targets.size()
	var chosen_value: Variant = valid_targets[idx]
	var choice_index: int = _choice_data.get("choice_index", 0)
	_log("[color=gray](CPU) > %d[/color]" % [idx + 1])
	_waiting_choice = false
	session.send_choice(choice_index, chosen_value)


# =============================================================================
# アクション処理
# =============================================================================

func _handle_action_input(num: int) -> void:
	if num < 1 or num > _current_actions.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % _current_actions.size())
		return

	var action: Dictionary = _current_actions[num - 1]
	_log("> %d" % num)
	session.send_action(action)


func _handle_choice_input(num: int) -> void:
	var valid_targets: Array = _choice_data.get("valid_targets", [])
	var choice_index: int = _choice_data.get("choice_index", 0)

	if num < 1 or num > valid_targets.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % valid_targets.size())
		return

	var chosen_value: Variant = valid_targets[num - 1]
	_log("> %d" % num)
	_waiting_choice = false
	session.send_choice(choice_index, chosen_value)


# =============================================================================
# 表示
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
	lines.append("")

	for p in range(2):
		var color: String = "white" if p != cs.current_player else "green"
		lines.append("[color=%s]--- Player %d ---[/color]" % [color, p])

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
		for i in range(empty_count):
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
		lines.append("  Rank: %s" % DisplayHelper.format_stage_rank(stage_cards))

		# Live ready
		var live_str: String = "Yes (turn %d)" % cs.live_ready_turn[p] if cs.live_ready[p] else "No"
		lines.append("  Live Ready: %s" % live_str)
		lines.append("")

	_state_display.clear()
	_state_display.append_text("\n".join(lines))


# =============================================================================
# ログ
# =============================================================================

func _log(msg: String) -> void:
	_log_display.append_text(msg + "\n")

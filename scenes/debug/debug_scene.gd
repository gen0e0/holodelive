extends Control

# --- セッション ---
var session: LocalGameSession

# --- UI ノード ---
@onready var _btn_restart: Button = %BtnRestart
@onready var _seed_input: LineEdit = %SeedInput
@onready var _seed_display: LineEdit = %SeedDisplay
@onready var _state_display: RichTextLabel = %StateDisplay
@onready var _log_display: RichTextLabel = %LogDisplay
@onready var _input_line: LineEdit = %InputLine
@onready var _btn_send: Button = %BtnSend
@onready var _cpu_toggle: CheckButton = %CpuToggle
@onready var _cpu_speed_input: LineEdit = %CpuSpeedInput
@onready var _gui_toggle: CheckButton = %GuiToggle

# --- GUI ペイン ---
@onready var _vsplit: VSplitContainer = %VSplit
@onready var _state_panel: PanelContainer = %StatePanel
@onready var _gui_container: Control = %GuiContainer
var _game_screen: GameScreen

# --- 内部状態 ---
var _rng: RandomNumberGenerator
var _current_actions: Array = []
var _waiting_choice: bool = false
var _choice_data: Dictionary = {}
var _auto_epoch: int = 0


func _ready() -> void:
	_btn_restart.pressed.connect(_on_restart_pressed)
	_btn_send.pressed.connect(_on_send_pressed)
	_input_line.text_submitted.connect(_on_text_submitted)
	_gui_toggle.toggled.connect(_on_gui_toggled)
	_init_and_start()


# =============================================================================
# ゲーム初期化・開始
# =============================================================================

func _init_and_start() -> void:
	# RNG 作成（シード指定があれば固定、なければランダム）
	_rng = RandomNumberGenerator.new()
	var seed_text: String = _seed_input.text.strip_edges()
	if seed_text.is_valid_int():
		_rng.seed = seed_text.to_int()
	else:
		_rng.randomize()
	_seed_display.text = str(_rng.seed)

	session = LocalGameSession.new()
	session.human_player = 0
	session.rng = _rng
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
	_state_display.text = ""
	_btn_send.disabled = true

	# GUI モードが有効なら GameScreen を接続
	if _gui_toggle.button_pressed:
		_ensure_game_screen()
		_game_screen.connect_session(session)

	_log("[color=yellow]--- Game Starting (seed: %d) ---[/color]" % _rng.seed)
	session.start_game()


func _on_restart_pressed() -> void:
	if _game_screen != null and session != null:
		_game_screen.disconnect_session()
	_init_and_start()


# =============================================================================
# ボタンハンドラ
# =============================================================================

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


# =============================================================================
# GUI モード切替
# =============================================================================

func _ensure_game_screen() -> void:
	if _game_screen == null:
		var scene: PackedScene = preload("res://scenes/gui/game_screen.tscn")
		_game_screen = scene.instantiate()
		_gui_container.add_child(_game_screen)


func _on_gui_toggled(enabled: bool) -> void:
	_state_panel.visible = not enabled
	_gui_container.visible = enabled
	if enabled:
		_ensure_game_screen()
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
	var idx: int = _rng.randi() % _current_actions.size()
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
	var idx: int = _rng.randi() % valid_targets.size()
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

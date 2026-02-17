extends Control

# --- 参照 ---
var registry: CardRegistry
var state: GameState
var controller: GameController

# --- UI ノード ---
var _btn_init: Button
var _btn_start: Button
var _state_display: RichTextLabel
var _log_display: RichTextLabel
var _input_line: LineEdit
var _btn_send: Button

# --- 内部状態 ---
var _last_action_log_size: int = 0
var _current_actions: Array = []
var _waiting_choice: bool = false


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

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	# --- 右ペイン ---
	var vsplit := VSplitContainer.new()
	vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(vsplit)

	# 上: 状態コンソール
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

	# 下: ログ + 入力
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
# ボタンハンドラ
# =============================================================================

func _on_init_pressed() -> void:
	registry = CardFactory.create_test_registry(20)
	state = GameSetup.setup_game(registry)
	controller = GameController.new(state, registry)
	_last_action_log_size = 0
	_current_actions = []
	_waiting_choice = false

	_log_display.clear()
	_log("[color=yellow]--- Game Initialized (20 test cards) ---[/color]")
	_log("P0 hand: %s" % _format_id_list(state.hands[0]))
	_log("P1 hand: %s" % _format_id_list(state.hands[1]))
	_log("Deck: %d cards" % state.deck.size())

	_btn_start.disabled = false
	_btn_send.disabled = true
	_update_state_display()


func _on_start_pressed() -> void:
	_btn_start.disabled = true
	_log("")
	_log("[color=yellow]--- Game Started ---[/color]")
	_do_start_turn()


func _on_send_pressed() -> void:
	var text := _input_line.text.strip_edges()
	_input_line.clear()
	if text.is_empty():
		text = "1"

	if not text.is_valid_int():
		_log("[color=red]Invalid input: enter a number.[/color]")
		return

	var num := text.to_int()

	if _waiting_choice:
		_handle_choice_input(num)
	else:
		_handle_action_input(num)


func _on_text_submitted(_text: String) -> void:
	_on_send_pressed()


# =============================================================================
# ゲームフロー
# =============================================================================

func _do_start_turn(depth: int = 0) -> void:
	if depth > 10:
		_log("[color=red]Turn recursion limit reached![/color]")
		return

	if controller.is_game_over():
		_show_game_over()
		return

	var prev_turn := state.turn_number
	_log("")
	_log("[color=cyan][T%d] P%d: Turn Start[/color]" % [state.turn_number, state.current_player])

	var live_happened := controller.start_turn()

	_log_recent_actions()

	if live_happened:
		# ライブ発動 → ラウンド終了処理済み
		if controller.is_game_over():
			_show_game_over()
			return
		# 次ターン自動開始
		_update_state_display()
		_do_start_turn(depth + 1)
		return

	_update_state_display()
	_show_available_actions()


func _handle_action_input(num: int) -> void:
	if num < 1 or num > _current_actions.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % _current_actions.size())
		return

	var action: Dictionary = _current_actions[num - 1]
	var prev_turn := state.turn_number
	_log("> %d" % num)

	controller.apply_action(action)
	_log_recent_actions()
	_advance_game_after(prev_turn)


func _handle_choice_input(num: int) -> void:
	# PendingChoice の選択肢をインデックスで選ぶ
	var pc: PendingChoice = _get_active_pending_choice()
	if pc == null:
		_log("[color=red]No pending choice.[/color]")
		_waiting_choice = false
		return

	if num < 1 or num > pc.valid_targets.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % pc.valid_targets.size())
		return

	var chosen_value: Variant = pc.valid_targets[num - 1]
	var prev_turn := state.turn_number
	_log("> %d" % num)

	var choice_idx := state.pending_choices.find(pc)
	controller.submit_choice(choice_idx, chosen_value)
	_waiting_choice = false
	_log_recent_actions()
	_advance_game_after(prev_turn)


func _advance_game_after(prev_turn: int) -> void:
	if controller.is_game_over():
		_update_state_display()
		_show_game_over()
		return

	if controller.is_waiting_for_choice():
		_update_state_display()
		var pc := _get_active_pending_choice()
		if pc:
			_show_choices(pc)
		return

	if state.turn_number != prev_turn:
		# ターンが進んだ → 自動でターン開始
		_update_state_display()
		_do_start_turn()
		return

	# 同一ターン継続
	_update_state_display()
	_show_available_actions()


# =============================================================================
# 表示
# =============================================================================

func _show_available_actions() -> void:
	_current_actions = controller.get_available_actions()
	_waiting_choice = false
	_btn_send.disabled = false

	_log("[color=green]Available actions:[/color]")
	for i in range(_current_actions.size()):
		_log("  %d. %s" % [i + 1, _format_action(_current_actions[i])])

	_input_line.call_deferred("grab_focus")


func _show_choices(pc: PendingChoice) -> void:
	_waiting_choice = true
	_btn_send.disabled = false

	_log("[color=green]Choose (for P%d):[/color]" % pc.target_player)
	for i in range(pc.valid_targets.size()):
		var target: Variant = pc.valid_targets[i]
		if target is int and target == -1:
			_log("  %d. Pass (decline)" % [i + 1])
		elif target is int:
			_log("  %d. %s" % [i + 1, _format_card(target)])
		else:
			_log("  %d. %s" % [i + 1, str(target)])

	_input_line.call_deferred("grab_focus")


func _show_game_over() -> void:
	var winner := controller.get_winner()
	_log("")
	_log("[color=yellow]========================================[/color]")
	_log("[color=yellow]  GAME OVER — Player %d Wins!  [/color]" % winner)
	_log("[color=yellow]  Rounds: P0=%d  P1=%d[/color]" % [state.round_wins[0], state.round_wins[1]])
	_log("[color=yellow]========================================[/color]")
	_btn_send.disabled = true
	_btn_init.disabled = false
	_update_state_display()


func _update_state_display() -> void:
	if state == null:
		_state_display.text = ""
		return

	var phase_name := ""
	match state.phase:
		Enums.Phase.ACTION: phase_name = "ACTION"
		Enums.Phase.PLAY: phase_name = "PLAY"
		Enums.Phase.LIVE: phase_name = "LIVE"
		Enums.Phase.SHOWDOWN: phase_name = "SHOWDOWN"

	var lines: Array[String] = []
	lines.append("[color=cyan]=== Round %d | Turn %d | P%d | Phase: %s ===[/color]" % [
		state.round_number, state.turn_number, state.current_player, phase_name
	])
	lines.append("Wins: P0=%d P1=%d | Deck: %d | Home: %d | Removed: %d" % [
		state.round_wins[0], state.round_wins[1],
		state.deck.size(), state.home.size(), state.removed.size()
	])
	lines.append("")

	for p in range(2):
		var color := "white" if p != state.current_player else "green"
		lines.append("[color=%s]--- Player %d ---[/color]" % [color, p])

		# Hand
		var hand_str := ""
		if state.hands[p].is_empty():
			hand_str = "(empty)"
		else:
			var parts: Array[String] = []
			for inst_id in state.hands[p]:
				parts.append("[%s]" % _format_card(inst_id))
			hand_str = " ".join(parts)
		lines.append("  Hand: %s" % hand_str)

		# Stage
		var stage_parts: Array[String] = []
		for s in range(3):
			var slot_id: int = state.stages[p][s]
			if slot_id == -1:
				stage_parts.append("[%d: empty]" % s)
			else:
				stage_parts.append("[%d: %s]" % [s, _format_card(slot_id)])
		lines.append("  Stage: %s" % " ".join(stage_parts))

		# Backstage
		var bs_id: int = state.backstages[p]
		if bs_id == -1:
			lines.append("  Backstage: empty")
		else:
			var bs_inst: CardInstance = state.instances[bs_id]
			if bs_inst.face_down:
				lines.append("  Backstage: #%d (face down)" % bs_id)
			else:
				lines.append("  Backstage: %s" % _format_card(bs_id))

		# Live ready
		var live_str := "Yes (turn %d)" % state.live_ready_turn[p] if state.live_ready[p] else "No"
		lines.append("  Live Ready: %s" % live_str)
		lines.append("")

	_state_display.clear()
	_state_display.append_text("\n".join(lines))


# =============================================================================
# ログ
# =============================================================================

func _log(msg: String) -> void:
	_log_display.append_text(msg + "\n")


func _log_recent_actions() -> void:
	while _last_action_log_size < state.action_log.size():
		var ga: GameAction = state.action_log[_last_action_log_size]
		_last_action_log_size += 1
		var text := _format_game_action(ga)
		if not text.is_empty():
			_log(text)


# =============================================================================
# フォーマット
# =============================================================================

func _format_card(inst_id: int) -> String:
	if not state.instances.has(inst_id):
		return "#%d (unknown)" % inst_id
	var inst: CardInstance = state.instances[inst_id]
	var card_def: CardDef = registry.get_card(inst.card_id)
	if not card_def:
		return "#%d cid=%d" % [inst_id, inst.card_id]
	var icons := inst.effective_icons(card_def)
	var suits := inst.effective_suits(card_def)
	return "#%d %s (%s|%s)" % [inst_id, card_def.nickname, ",".join(icons), ",".join(suits)]


func _format_id_list(ids: Array) -> String:
	var parts: Array[String] = []
	for inst_id in ids:
		parts.append(_format_card(inst_id))
	return ", ".join(parts)


func _format_action(action: Dictionary) -> String:
	var atype: Enums.ActionType = action["type"]
	match atype:
		Enums.ActionType.PASS:
			return "Pass"
		Enums.ActionType.OPEN:
			return "Open backstage %s" % _format_card(action["instance_id"])
		Enums.ActionType.PLAY_CARD:
			var target: String = action["target"]
			var card_str := _format_card(action["instance_id"])
			if target == "stage":
				return "Play %s -> Stage[%d]" % [card_str, action["slot"]]
			else:
				return "Play %s -> Backstage" % card_str
		Enums.ActionType.ACTIVATE_SKILL:
			var inst_id: int = action["instance_id"]
			var skill_idx: int = action["skill_index"]
			var card_str := _format_card(inst_id)
			return "Activate skill #%d of %s" % [skill_idx, card_str]
		_:
			return str(action)


func _format_game_action(ga: GameAction) -> String:
	var prefix := "[T%d] P%d: " % [state.turn_number, ga.player]
	match ga.type:
		Enums.ActionType.DRAW:
			var inst_id: int = ga.params.get("instance_id", -1)
			return prefix + "Drew %s" % _format_card(inst_id)
		Enums.ActionType.PASS:
			return prefix + "Pass (%s)" % _phase_name()
		Enums.ActionType.OPEN:
			return prefix + "Opened backstage %s" % _format_card(ga.params.get("instance_id", -1))
		Enums.ActionType.PLAY_CARD:
			var target: String = ga.params.get("target", "")
			var card_str := _format_card(ga.params.get("instance_id", -1))
			if target == "stage":
				return prefix + "Played %s -> Stage[%d]" % [card_str, ga.params.get("slot", -1)]
			else:
				return prefix + "Played %s -> Backstage" % card_str
		Enums.ActionType.ACTIVATE_SKILL:
			return prefix + "Activated skill of %s" % _format_card(ga.params.get("instance_id", -1))
		Enums.ActionType.ROUND_END:
			var winner: int = ga.params.get("winner", -1)
			return "[color=yellow]--- Round End: Player %d wins! (P0=%d P1=%d) ---[/color]" % [
				winner, state.round_wins[0], state.round_wins[1]
			]
		Enums.ActionType.TURN_START:
			return ""  # ターン開始は _do_start_turn で別途ログ
		Enums.ActionType.TURN_END:
			return ""  # 暗黙
		_:
			return prefix + str(ga.type)


func _phase_name() -> String:
	match state.phase:
		Enums.Phase.ACTION: return "ACTION"
		Enums.Phase.PLAY: return "PLAY"
		Enums.Phase.LIVE: return "LIVE"
		Enums.Phase.SHOWDOWN: return "SHOWDOWN"
		_: return "?"


func _get_active_pending_choice() -> PendingChoice:
	for pc in state.pending_choices:
		if not pc.resolved:
			return pc
	return null

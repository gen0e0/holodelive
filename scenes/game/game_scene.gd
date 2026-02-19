extends Control

# --- Session ---
var session: GameSession

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


func _ready() -> void:
	_build_ui()

	var nm: Node = get_node("/root/NetworkManager")
	var client: GameClient = nm.get_client()
	session = NetworkGameSession.new(client)

	session.state_updated.connect(_on_state_updated)
	session.actions_received.connect(_on_actions_received)
	session.choice_requested.connect(_on_choice_requested)
	session.game_started.connect(_on_game_started)
	session.game_over.connect(_on_game_over)

	# Display which player we are
	if nm.is_host:
		_player_label.text = "You are Player 0 (Host)"
	else:
		_player_label.text = "You are Player 1 (Guest)"

	# Host starts the game after a short delay to ensure guest scene is ready
	if nm.is_host:
		await get_tree().create_timer(1.0).timeout
		var server: GameServer = nm.get_server()
		if server:
			server.start_game()


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
# Session signal handlers
# =============================================================================

func _on_game_started() -> void:
	_log("[color=yellow]--- Game Started ---[/color]")


func _on_state_updated(client_state: ClientState, events: Array) -> void:
	_update_state_display(client_state)
	for event in events:
		var text: String = _format_event(event)
		if not text.is_empty():
			_log(text)


func _on_actions_received(actions: Array) -> void:
	_current_actions = actions
	_waiting_choice = false
	_btn_send.disabled = false

	var phase_name: String = _get_phase_name()
	_log("[color=green]Available actions (%s):[/color]" % phase_name)
	for i in range(_current_actions.size()):
		_log("  %d. %s" % [i + 1, _format_action(_current_actions[i])])

	_input_line.call_deferred("grab_focus")


func _on_choice_requested(choice_data_arg: Dictionary) -> void:
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
				_log("  %d. %s" % [i + 1, _format_card_dict(d)])
		else:
			_log("  %d. %s" % [i + 1, str(target)])

	_input_line.call_deferred("grab_focus")


func _on_game_over(winner: int) -> void:
	var cs: ClientState = session.get_client_state()
	_log("")
	_log("[color=yellow]========================================[/color]")
	_log("[color=yellow]  GAME OVER — Player %d Wins!  [/color]" % winner)
	if cs:
		_log("[color=yellow]  Rounds: P0=%d  P1=%d[/color]" % [cs.round_wins[0], cs.round_wins[1]])
	_log("[color=yellow]========================================[/color]")
	_btn_send.disabled = true


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
	_btn_send.disabled = true
	session.send_choice(choice_index, chosen_value)


# =============================================================================
# Display
# =============================================================================

func _update_state_display(cs: ClientState) -> void:
	if cs == null:
		_state_display.text = ""
		return

	var phase_name: String = ""
	match cs.phase:
		Enums.Phase.ACTION: phase_name = "ACTION"
		Enums.Phase.PLAY: phase_name = "PLAY"
		Enums.Phase.LIVE: phase_name = "LIVE"
		Enums.Phase.SHOWDOWN: phase_name = "SHOWDOWN"

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
					parts.append("[%s]" % _format_card_dict(d))
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
				stage_parts.append("[%s]" % _format_card_dict(dict))
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
				lines.append("  Backstage: %s" % _format_card_dict(bs_dict))

		# Live ready
		var live_str: String = "Yes (turn %d)" % cs.live_ready_turn[p] if cs.live_ready[p] else "No"
		lines.append("  Live Ready: %s" % live_str)
		lines.append("")

	_state_display.clear()
	_state_display.append_text("\n".join(lines))


# =============================================================================
# Log
# =============================================================================

func _log(msg: String) -> void:
	_log_display.append_text(msg + "\n")


# =============================================================================
# Format helpers
# =============================================================================

func _format_card_dict(d: Dictionary) -> String:
	if d.get("hidden", false):
		return "<hidden>"
	var card_id: int = d.get("card_id", -1)
	var nickname: String = d.get("nickname", "?")
	var icons: Array = d.get("icons", [])
	var suits: Array = d.get("suits", [])
	var icon_abbrs: Array[String] = []
	for ic in icons:
		icon_abbrs.append(str(ic).left(3))
	var suit_abbrs: Array[String] = []
	for su in suits:
		suit_abbrs.append(str(su).left(3))
	return "<#%03d %s %s-%s>" % [
		card_id,
		nickname.left(3),
		",".join(icon_abbrs),
		",".join(suit_abbrs)
	]


func _format_action(action: Dictionary) -> String:
	var atype: Enums.ActionType = action["type"]
	match atype:
		Enums.ActionType.PASS:
			return "Pass"
		Enums.ActionType.OPEN:
			var card_str: String = _lookup_card_label(action.get("instance_id", -1))
			return "Open backstage %s" % card_str
		Enums.ActionType.PLAY_CARD:
			var target: String = action.get("target", "")
			var card_str: String = _lookup_card_label(action.get("instance_id", -1))
			if target == "stage":
				return "Play %s -> Stage" % card_str
			else:
				return "Play %s -> Backstage" % card_str
		Enums.ActionType.ACTIVATE_SKILL:
			var skill_idx: int = action.get("skill_index", 0)
			var card_str: String = _lookup_card_label(action.get("instance_id", -1))
			return "Activate skill #%d of %s" % [skill_idx, card_str]
		_:
			return str(action)


func _format_event(event: Dictionary) -> String:
	var type: String = event.get("type", "")
	var player: int = event.get("player", 0)
	var cs: ClientState = session.get_client_state()
	var turn: int = cs.turn_number if cs else 0
	var prefix: String = "[T%d] P%d: " % [turn, player]

	match type:
		"DRAW":
			var card: Variant = event.get("card")
			if card != null:
				return prefix + "Drew %s" % _format_card_dict(card)
			else:
				return prefix + "Drew a card"
		"PASS":
			return prefix + "Pass (%s)" % _get_phase_name()
		"OPEN":
			var card: Variant = event.get("card")
			if card != null:
				return prefix + "Opened backstage %s" % _format_card_dict(card)
			return prefix + "Opened backstage"
		"PLAY_CARD":
			var card: Variant = event.get("card")
			var target: String = event.get("target", "")
			var card_str: String = _format_card_dict(card) if card != null else "?"
			if target == "stage":
				return prefix + "Played %s -> Stage" % card_str
			else:
				return prefix + "Played %s -> Backstage" % card_str
		"ACTIVATE_SKILL":
			var card: Variant = event.get("card")
			var card_str: String = _format_card_dict(card) if card != null else "?"
			return prefix + "Activated skill of %s" % card_str
		"ROUND_END":
			var winner: int = event.get("winner", -1)
			if cs:
				return "[color=yellow]--- Round End: Player %d wins! (P0=%d P1=%d) ---[/color]" % [
					winner, cs.round_wins[0], cs.round_wins[1]
				]
			return "[color=yellow]--- Round End: Player %d wins! ---[/color]" % winner
		"TURN_START":
			return ""
		"TURN_END":
			return ""

	return ""


func _lookup_card_label(instance_id: int) -> String:
	var cs: ClientState = session.get_client_state() if session else null
	if cs == null:
		return "#?"
	for d in cs.my_hand:
		if d.get("instance_id", -1) == instance_id:
			return _format_card_dict(d)
	for p in range(2):
		for d in cs.stages[p]:
			if d.get("instance_id", -1) == instance_id:
				return _format_card_dict(d)
		if cs.backstages[p] != null:
			var d: Dictionary = cs.backstages[p]
			if d.get("instance_id", -1) == instance_id:
				return _format_card_dict(d)
	for d in cs.home:
		if d.get("instance_id", -1) == instance_id:
			return _format_card_dict(d)
	for d in cs.removed:
		if d.get("instance_id", -1) == instance_id:
			return _format_card_dict(d)
	return "#?"


func _get_phase_name() -> String:
	var cs: ClientState = session.get_client_state() if session else null
	if cs == null:
		return "?"
	match cs.phase:
		Enums.Phase.ACTION: return "ACTION"
		Enums.Phase.PLAY: return "PLAY"
		Enums.Phase.LIVE: return "LIVE"
		Enums.Phase.SHOWDOWN: return "SHOWDOWN"
		_: return "?"

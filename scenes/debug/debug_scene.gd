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

# --- Zone Edit ---
@onready var _player_select: OptionButton = %PlayerSelect
@onready var _zone_select: OptionButton = %ZoneSelect
@onready var _card_id_input: LineEdit = %CardIdInput
@onready var _card_preview: Label = %CardPreview
@onready var _btn_add_card: Button = %BtnAddCard
@onready var _btn_clear_zone: Button = %BtnClearZone

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
var _zone_overrides: Dictionary = {}  # e.g. {"h0": [6, 3], "s1": [40]}
var _auto_queue: Array = []  # CLI自動行動キュー Array[Dictionary]
var _p0_controller: HumanPlayerController
var _cpu_both: bool = false  # 両プレイヤーCPU（CLIテスト用）
var _max_turns: int = 0      # ターン制限（0=無制限）


func _ready() -> void:
	_btn_restart.pressed.connect(_on_restart_pressed)
	_btn_send.pressed.connect(_on_send_pressed)
	_input_line.text_submitted.connect(_on_text_submitted)
	_gui_toggle.toggled.connect(_on_gui_toggled)
	_btn_add_card.pressed.connect(_on_add_card_pressed)
	_btn_clear_zone.pressed.connect(_on_clear_zone_pressed)
	_card_id_input.text_changed.connect(_on_card_id_text_changed)
	_card_id_input.text_submitted.connect(_on_card_id_submitted)
	_init_and_start()


# =============================================================================
# ゲーム初期化・開始
# =============================================================================

func _init_and_start() -> void:
	# コマンドライン引数からゾーンオーバーライドをパース
	# test=ID 形式ならプリセットから展開
	var user_args: Array = OS.get_cmdline_user_args()
	var resolved_args: Array = _resolve_test_preset(user_args)
	_zone_overrides = _parse_zone_args(resolved_args)
	_auto_queue = _parse_auto_args(resolved_args)
	_cpu_both = _parse_flag(resolved_args, "cpu", "") == "both"
	var max_turns_str: String = _parse_flag(resolved_args, "max_turns", "0")
	_max_turns = max_turns_str.to_int() if max_turns_str.is_valid_int() else 0
	var speed_str: String = _parse_flag(resolved_args, "speed", "")
	if speed_str.is_valid_float() and speed_str.to_float() > 0.0:
		GameConfig.animation_speed = speed_str.to_float()
	elif _cpu_both:
		GameConfig.animation_speed = 50.0  # cpu=both デフォルト高速
	GameLog.reset()

	# RNG 作成（シード指定があれば固定、なければランダム）
	_rng = RandomNumberGenerator.new()
	var seed_text: String = _seed_input.text.strip_edges()
	if seed_text.is_valid_int():
		_rng.seed = seed_text.to_int()
	else:
		_rng.randomize()
	_seed_display.text = str(_rng.seed)

	session = LocalGameSession.new()
	session.viewing_player = 0
	session.rng = _rng
	session.state_updated.connect(_on_state_updated)
	session.game_started.connect(_on_game_started)
	session.game_over.connect(_on_game_over)

	_current_actions = []
	_waiting_choice = false
	_choice_data = {}
	_auto_epoch += 1

	_log_display.clear()
	_state_display.text = ""
	_btn_send.disabled = true

	# PlayerController を start_game 前に登録（Callable で state/registry を遅延取得）
	var get_state: Callable = func() -> GameState: return session.state
	var get_registry: Callable = func() -> CardRegistry: return session.registry

	# P0: 常に HumanPlayerController（cpu=both でも UI フロー経由）
	_p0_controller = HumanPlayerController.new()
	_p0_controller.actions_presented.connect(_on_actions_received)
	_p0_controller.choice_presented.connect(_on_choice_requested)
	session.set_player_controller(0, _p0_controller)

	var p1_delay: float = 0.01 if _cpu_both else 0.0
	session.set_player_controller(1, CpuPlayerController.new(
		RandomStrategy.new(_rng), get_state, get_registry, get_tree(), p1_delay))

	# GameScreen 接続: GUI トグル ON または cpu=both（統合テストでは常に UI フロー使用）
	if _gui_toggle.button_pressed or _cpu_both:
		_ensure_game_screen()
		_game_screen.connect_session(session, _p0_controller)

	if _max_turns > 0:
		session.max_turns = _max_turns

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
	if not _zone_overrides.is_empty():
		_apply_zone_overrides()
		_zone_overrides = {}


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

	# CLI 自動行動キュー
	if not _auto_queue.is_empty():
		var entry: Dictionary = _auto_queue.pop_front()
		_schedule_auto_queue_action(entry)
		return
	if _cpu_both or _cpu_toggle.button_pressed:
		var delay: float = 0.0 if _cpu_both else _get_cpu_speed()
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

	# CLI 自動行動キュー
	if not _auto_queue.is_empty():
		var entry: Dictionary = _auto_queue.pop_front()
		_schedule_auto_queue_choice(entry)
		return
	if _cpu_both or _cpu_toggle.button_pressed:
		var delay: float = 0.0 if _cpu_both else _get_cpu_speed()
		_schedule_auto_choice(delay, _auto_epoch)
	else:
		_input_line.call_deferred("grab_focus")


func _on_game_over(winner: int) -> void:
	_auto_epoch += 1
	var cs: ClientState = session.get_client_state()
	_log("")
	_log("[color=yellow]========================================[/color]")
	if winner >= 0:
		_log("[color=yellow]  GAME OVER — Player %d Wins!  [/color]" % winner)
	else:
		_log("[color=yellow]  GAME OVER — Turn limit reached  [/color]")
	if cs:
		_log("[color=yellow]  Rounds: P0=%d  P1=%d  Turn: %d[/color]" % [
			cs.round_wins[0], cs.round_wins[1], cs.turn_number])
	_log("[color=yellow]========================================[/color]")
	_btn_send.disabled = true

	# cpu=both 時はプロセスを自動終了（ログフラッシュのため1フレーム待つ）
	if _cpu_both:
		await get_tree().process_frame
		get_tree().quit(0 if winner >= 0 else 1)


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
			_game_screen.connect_session(session, _p0_controller)
	else:
		if _game_screen != null and session != null:
			_game_screen.disconnect_session()


# =============================================================================
# CPU 自動応答
# =============================================================================

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
	if _game_screen != null:
		_game_screen.auto_respond_action(action)
	else:
		_do_submit_action(action)


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
	if _game_screen != null:
		_game_screen.auto_respond_choice(choice_index, chosen_value)
	else:
		_do_submit_choice(choice_index, chosen_value)


# =============================================================================
# アクション処理
# =============================================================================

func _handle_action_input(num: int) -> void:
	if num < 1 or num > _current_actions.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % _current_actions.size())
		return

	var action: Dictionary = _current_actions[num - 1]
	_log("> %d" % num)
	_do_submit_action(action)


func _handle_choice_input(num: int) -> void:
	var valid_targets: Array = _choice_data.get("valid_targets", [])
	var choice_index: int = _choice_data.get("choice_index", 0)

	if num < 1 or num > valid_targets.size():
		_log("[color=red]Invalid choice: pick 1-%d[/color]" % valid_targets.size())
		return

	var chosen_value: Variant = valid_targets[num - 1]
	_log("> %d" % num)
	_waiting_choice = false
	_do_submit_choice(choice_index, chosen_value)


## アクション送信: GameScreen 経由（UI フロー）or 直接送信
func _do_submit_action(action: Dictionary) -> void:
	if _game_screen != null:
		_game_screen.auto_respond_action(action)
	else:
		_p0_controller.submit_action(action)


## チョイス送信: GameScreen 経由（UI フロー）or 直接送信
func _do_submit_choice(choice_idx: int, value: Variant) -> void:
	if _game_screen != null:
		_game_screen.auto_respond_choice(choice_idx, value)
	else:
		_p0_controller.submit_choice(choice_idx, value)


# =============================================================================
# コマンドライン引数によるゾーンオーバーライド
# =============================================================================

## test=ID 引数があればプリセットJSONから展開、なければ引数をそのまま返す。
static func _resolve_test_preset(args: Array) -> Array:
	for arg in args:
		var a: String = str(arg)
		if a.begins_with("test="):
			var id: String = a.substr(5)
			var presets: Dictionary = _load_test_presets()
			if presets.has(id):
				var preset_args: Array = presets[id]
				print("[TestPreset] test=%s → %s" % [id, str(preset_args)])
				return preset_args
			push_warning("Test preset '%s' not found in test_presets.json" % id)
			return []
	return args


static func _load_test_presets() -> Dictionary:
	var path: String = "res://scenes/debug/test_presets.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open %s" % path)
		return {}
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_warning("Failed to parse %s: %s" % [path, json.get_error_message()])
		return {}
	return json.data if json.data is Dictionary else {}


## コマンドライン引数をパースしてゾーンオーバーライド辞書を返す。
## 引数形式: p0=6,3 s1=r,rg,40 b0=rg h=1,2 d=3,7,45  (-- セパレータ以降)
## キー: p0/p1=手札, s0/s1=ステージ, b0/b1=バックステージ, h=自宅(共有), d=デッキ先頭
## 値: Array[Dictionary] — 各要素 {"card_id": int, "guest": bool}
##   card_id: カードID または RANDOM_CARD (-1)
##   guest: true なら face_down（ゲスト状態）で配置
## トークン末尾に g を付けるとゲスト: 1g, rg
const RANDOM_CARD: int = -1

static func _parse_zone_args(args: Array) -> Dictionary:
	var result: Dictionary = {}
	var valid_keys: Array[String] = ["p0", "p1", "s0", "s1", "b0", "b1", "h", "d"]
	for arg in args:
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		var key: String = parts[0].strip_edges().to_lower()
		if key not in valid_keys:
			continue
		var val_str: String = parts[1].strip_edges()
		var entries: Array = []
		for token in val_str.split(","):
			var t: String = token.strip_edges().to_lower()
			var guest: bool = t.ends_with("g")
			if guest:
				t = t.substr(0, t.length() - 1)
			if t == "r":
				entries.append({"card_id": RANDOM_CARD, "guest": guest})
			elif t.is_valid_int():
				entries.append({"card_id": t.to_int(), "guest": guest})
		if not entries.is_empty():
			result[key] = entries
	return result


## _zone_overrides に基づいて session.state のゾーンを上書きする。
## デッキにある同一 card_id のインスタンスを優先移動し、なければ新規生成。
func _apply_zone_overrides() -> void:
	var state: GameState = session.state
	_log("[color=cyan][ZoneOverride] Applying overrides...[/color]")

	# デッキ先頭指定は先に処理（他のゾーン配置でデッキから抜かれる前に順序を確保）
	if _zone_overrides.has("d"):
		_apply_deck_override(state, _zone_overrides["d"])

	for key in _zone_overrides:
		if key == "d":
			continue
		var card_entries: Array = _zone_overrides[key]
		var is_home: bool = (key == "h")
		var zone_char: String = key[0]  # p, s, b, h
		var player: int = key[1].to_int() if not is_home else -1

		# ターゲットゾーンをクリア
		match zone_char:
			"p":
				state.hands[player].clear()
			"s":
				state.stages[player].clear()
			"b":
				state.backstages[player] = -1
			"h":
				state.home.clear()

		# 各カードを配置
		for entry in card_entries:
			var card_id: int = entry["card_id"]
			var guest: bool = entry["guest"]
			var instance_id: int = -1
			var actual_card_id: int = card_id

			if card_id == RANDOM_CARD:
				# デッキからランダムに1枚引く
				if state.deck.is_empty():
					_log("[color=red][ZoneOverride] Deck empty, cannot pick random card.[/color]")
					continue
				var idx: int = _rng.randi() % state.deck.size()
				instance_id = state.deck[idx]
				state.deck.remove_at(idx)
				actual_card_id = state.instances[instance_id].card_id
			else:
				instance_id = _find_and_remove_from_current_zone(state, card_id)
				if instance_id == -1:
					instance_id = state.create_instance(card_id)

			if guest:
				state.instances[instance_id].face_down = true

			match zone_char:
				"p":
					state.hands[player].append(instance_id)
				"s":
					state.stages[player].append(instance_id)
				"b":
					state.backstages[player] = instance_id
				"h":
					state.home.append(instance_id)

			var card_def: CardDef = session.registry.get_card(actual_card_id)
			var card_name: String = card_def.nickname if card_def else "???"
			var guest_label: String = " [guest]" if guest else ""
			var zone_name: String = {"p": "Hand", "s": "Stage", "b": "Backstage", "h": "Home"}[zone_char]
			if is_home:
				_log("[color=cyan][ZoneOverride] #%d %s → %s%s[/color]" % [
					actual_card_id, card_name, zone_name, guest_label])
			else:
				_log("[color=cyan][ZoneOverride] #%d %s → P%d %s%s[/color]" % [
					actual_card_id, card_name, player, zone_name, guest_label])


## デッキ先頭に指定カードを配置する。指定カードをデッキ内から探して先頭に移動。
## なければ新規生成してデッキ先頭に挿入。
func _apply_deck_override(state: GameState, entries: Array) -> void:
	# 逆順に処理して insert(0) すると、entries の順序がデッキ先頭に反映される
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		var card_id: int = entry["card_id"]
		if card_id == RANDOM_CARD:
			continue  # デッキ内ランダムは意味がないのでスキップ
		# デッキ内から探して先頭に移動
		var found: bool = false
		for j in range(state.deck.size()):
			var iid: int = state.deck[j]
			if state.instances[iid].card_id == card_id:
				state.deck.remove_at(j)
				state.deck.insert(0, iid)
				found = true
				break
		if not found:
			# デッキにない場合は新規生成して先頭に挿入
			var iid: int = state.create_instance(card_id)
			state.deck.insert(0, iid)
		var card_def: CardDef = session.registry.get_card(card_id)
		var card_name: String = card_def.nickname if card_def else "???"
		_log("[color=cyan][ZoneOverride] #%d %s → Deck top[/color]" % [card_id, card_name])


## state 内の全ゾーンから指定 card_id のインスタンスを探し、見つかれば除去して instance_id を返す。
## 見つからなければ -1。
static func _find_and_remove_from_current_zone(state: GameState, card_id: int) -> int:
	# デッキから探す（最も一般的）
	for i in range(state.deck.size()):
		var iid: int = state.deck[i]
		if state.instances[iid].card_id == card_id:
			state.deck.remove_at(i)
			return iid
	# 手札から探す
	for p in range(2):
		for i in range(state.hands[p].size()):
			var iid: int = state.hands[p][i]
			if state.instances[iid].card_id == card_id:
				state.hands[p].remove_at(i)
				return iid
	# ステージから探す
	for p in range(2):
		for i in range(state.stages[p].size()):
			var iid: int = state.stages[p][i]
			if state.instances[iid].card_id == card_id:
				state.stages[p].remove_at(i)
				return iid
	# バックステージから探す
	for p in range(2):
		if state.backstages[p] != -1:
			var iid: int = state.backstages[p]
			if state.instances[iid].card_id == card_id:
				state.backstages[p] = -1
				return iid
	# 自宅から探す
	for i in range(state.home.size()):
		var iid: int = state.home[i]
		if state.instances[iid].card_id == card_id:
			state.home.remove_at(i)
			return iid
	return -1


# =============================================================================
# Zone Edit
# =============================================================================

const ZONE_KEYS: Array[String] = ["Hand", "Stage", "Backstage"]


func _on_card_id_text_changed(new_text: String) -> void:
	var text: String = new_text.strip_edges()
	if session == null or not text.is_valid_int():
		_card_preview.text = ""
		return
	var card_def: CardDef = session.registry.get_card(text.to_int())
	_card_preview.text = card_def.nickname if card_def else ""


func _on_card_id_submitted(_text: String) -> void:
	_on_add_card_pressed()


func _on_add_card_pressed() -> void:
	if session == null:
		_log("[color=red]No active session.[/color]")
		return
	var text: String = _card_id_input.text.strip_edges()
	if not text.is_valid_int():
		_log("[color=red]Invalid card ID.[/color]")
		return
	var card_id: int = text.to_int()
	var state: GameState = session.state
	var card_def: CardDef = session.registry.get_card(card_id)
	if card_def == null:
		_log("[color=red]Card ID %d not found in registry.[/color]" % card_id)
		return

	var p: int = _player_select.selected
	var zone_idx: int = _zone_select.selected
	var instance_id: int = state.create_instance(card_id)

	match zone_idx:
		0:  # Hand
			state.hands[p].append(instance_id)
		1:  # Stage
			state.stages[p].append(instance_id)
		2:  # Backstage
			state.backstages[p] = instance_id

	_log("[color=cyan][ZoneEdit] Added %s (inst#%d) to P%d %s[/color]" % [
		card_def.nickname, instance_id, p, ZONE_KEYS[zone_idx]])
	session._flush_updates()
	session._request_actions()


func _on_clear_zone_pressed() -> void:
	if session == null:
		_log("[color=red]No active session.[/color]")
		return
	var p: int = _player_select.selected
	var zone_idx: int = _zone_select.selected
	var state: GameState = session.state

	match zone_idx:
		0:  # Hand
			state.hands[p].clear()
		1:  # Stage
			state.stages[p].clear()
		2:  # Backstage
			state.backstages[p] = -1

	_log("[color=cyan][ZoneEdit] Cleared P%d %s[/color]" % [p, ZONE_KEYS[zone_idx]])
	session._flush_updates()
	session._request_actions()


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
# CLI 自動行動キュー
# =============================================================================

## key=value 形式の引数を探して value を返す。見つからなければ default_value。
static func _parse_flag(args: Array, key: String, default_value: String) -> String:
	var prefix: String = key + "="
	for arg in args:
		var a: String = str(arg)
		if a.begins_with(prefix):
			return a.substr(prefix.length()).strip_edges()
	return default_value


## auto=play:3:stage,select:7,pass,select:3:stage 形式をパース。
static func _parse_auto_args(args: Array) -> Array:
	for arg in args:
		var a: String = str(arg)
		if a.begins_with("auto="):
			var tokens: PackedStringArray = a.substr(5).split(",")
			var result: Array = []
			for token in tokens:
				var entry: Dictionary = _parse_auto_token(token.strip_edges())
				if not entry.is_empty():
					result.append(entry)
			return result
	return []


static func _parse_auto_token(token: String) -> Dictionary:
	var parts: PackedStringArray = token.split(":")
	if parts.is_empty():
		return {}
	var cmd: String = parts[0].to_lower()
	match cmd:
		"play":
			if parts.size() < 3:
				return {}
			return {"cmd": "play", "card_id": parts[1].to_int(), "target": parts[2]}
		"select":
			if parts.size() >= 3:
				return {"cmd": "select", "card_id": parts[1].to_int(), "zone": parts[2]}
			elif parts.size() >= 2:
				return {"cmd": "select", "card_id": parts[1].to_int()}
			return {}
		"pass":
			return {"cmd": "pass"}
	return {}


func _schedule_auto_queue_action(entry: Dictionary) -> void:
	await get_tree().process_frame
	var cmd: String = entry.get("cmd", "")
	match cmd:
		"play":
			var card_id: int = entry.get("card_id", -1)
			var target: String = entry.get("target", "stage")
			var action: Dictionary = _find_play_action(card_id, target)
			if action.is_empty():
				_log("[color=red][Auto] No PLAY_CARD for card_id=%d target=%s[/color]" % [card_id, target])
				return
			GameLog.log_event("ACTION", "auto_play", {"card_id": card_id, "target": target})
			_log("[color=magenta](Auto) play:%d:%s[/color]" % [card_id, target])
			_do_submit_action(action)
		"pass":
			var action: Dictionary = _find_pass_action()
			if action.is_empty():
				_log("[color=red][Auto] No PASS action available[/color]")
				return
			GameLog.log_event("ACTION", "auto_pass")
			_log("[color=magenta](Auto) pass[/color]")
			_do_submit_action(action)
		_:
			_log("[color=red][Auto] Unexpected cmd '%s' for action[/color]" % cmd)


func _schedule_auto_queue_choice(entry: Dictionary) -> void:
	await get_tree().process_frame
	var cmd: String = entry.get("cmd", "")
	var choice_index: int = _choice_data.get("choice_index", 0)
	var valid_targets: Array = _choice_data.get("valid_targets", [])

	if cmd == "select":
		var card_id: int = entry.get("card_id", -1)
		# valid_targets から card_id に一致する instance_id を探す
		for target in valid_targets:
			if target is int and target >= 0:
				var inst: CardInstance = session.state.instances.get(target)
				if inst != null and inst.card_id == card_id:
					# ゾーン指定があれば次の SELECT_ZONE 用にキューに挿入
					if entry.has("zone"):
						_auto_queue.push_front({"cmd": "_zone", "zone": entry["zone"]})
					GameLog.log_event("CHOICE", "auto_select", {"card_id": card_id, "iid": target})
					_log("[color=magenta](Auto) select:%d[/color]" % card_id)
					_waiting_choice = false
					_do_submit_choice(choice_index, target)
					return
		_log("[color=red][Auto] No matching target for card_id=%d in %s[/color]" % [card_id, str(valid_targets)])
	elif cmd == "_zone":
		# 内部コマンド: SELECT_ZONE の自動応答
		var zone: String = entry.get("zone", "")
		for target in valid_targets:
			if str(target) == zone:
				GameLog.log_event("CHOICE", "auto_zone", {"zone": zone})
				_log("[color=magenta](Auto) zone:%s[/color]" % zone)
				_waiting_choice = false
				_do_submit_choice(choice_index, target)
				return
		_log("[color=red][Auto] Zone '%s' not in valid_targets %s[/color]" % [zone, str(valid_targets)])
	else:
		_log("[color=red][Auto] Unexpected cmd '%s' for choice[/color]" % cmd)


func _find_play_action(card_id: int, target: String) -> Dictionary:
	for a in _current_actions:
		if a.get("type") != Enums.ActionType.PLAY_CARD:
			continue
		if a.get("target", "") != target:
			continue
		var iid: int = a.get("instance_id", -1)
		var inst: CardInstance = session.state.instances.get(iid)
		if inst != null and inst.card_id == card_id:
			return a
	return {}


func _find_pass_action() -> Dictionary:
	for a in _current_actions:
		if a.get("type") == Enums.ActionType.PASS:
			return a
	return {}


# =============================================================================
# ログ
# =============================================================================

func _log(msg: String) -> void:
	_log_display.append_text(msg + "\n")

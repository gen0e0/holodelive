class_name GameScreen
extends Control

## GUI ルートコンポーネント。
## GameSession のシグナルを受けて TopBar / FieldLayout / CardLayer を更新する。
## 内部は 1920x1080 固定座標で描画し、親サイズに合わせてスケーリングする。
##
## tscn から使用する場合、以下のノード構成が必要:
##   GameScreen (Control + this script)
##     └── Content (Control, size 1920x1080)
##           ├── Background (ColorRect, 1920x1080)
##           ├── TopBar (HBoxContainer + top_bar.gd)
##           ├── FieldLayout (Control + field_layout.gd)
##           └── CardLayer (Control + card_layer.gd)

const DESIGN_W: float = 1920.0
const DESIGN_H: float = 1080.0

var session: GameSession

var _current_actions: Array = []
var _selected_instance_id: int = -1

@onready var _content: Control = $Content
@onready var _top_bar: TopBar = $Content/TopBar
@onready var _field_layout: FieldLayout = $Content/FieldLayout
@onready var _card_layer: CardLayer = $Content/CardLayer
@onready var _my_hand: HandZone = $Content/MyHandZone
@onready var _opp_hand: HandZone = $Content/OppHandZone

var _overlay: Control
var _btn_stage: Button
var _btn_backstage: Button
var _btn_pass: Button
var _action_buttons: Array = []  # ACTION フェーズ用の動的ボタン


func _ready() -> void:
	_my_hand.card_clicked.connect(_on_hand_card_clicked)
	_setup_buttons()


func _make_overlay_button(text: String, rect: Rect2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = rect.position
	btn.size = rect.size
	btn.modulate = Color(1, 1, 1, 0.85)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.8, 0.35)
	style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.3, 0.6, 0.9, 0.5)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.4, 0.7, 0.5)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_font_size_override("font_size", 28)
	btn.visible = false
	return btn


func _setup_buttons() -> void:
	_overlay = Control.new()
	_overlay.z_index = 100
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_overlay)

	# ステージ全体を覆うボタン (MyStage1-3: x=24-948, y=80-500)
	_btn_stage = _make_overlay_button("ステージにプレイ", Rect2(24, 80, 924, 420))
	_btn_stage.pressed.connect(_on_stage_pressed)
	_overlay.add_child(_btn_stage)

	# 楽屋全体を覆うボタン (MyBackstage: x=648-948, y=530-950)
	_btn_backstage = _make_overlay_button("楽屋にプレイ", Rect2(648, 530, 300, 420))
	_btn_backstage.pressed.connect(_on_backstage_pressed)
	_overlay.add_child(_btn_backstage)

	# パスボタン（カードが出せない時のみ表示）
	_btn_pass = _make_overlay_button("パス", Rect2(360, 430, 200, 60))
	_btn_pass.pressed.connect(_on_pass_pressed)
	_overlay.add_child(_btn_pass)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_content()


func _fit_content() -> void:
	if _content == null:
		return
	var s: float = minf(size.x / DESIGN_W, size.y / DESIGN_H)
	_content.scale = Vector2(s, s)
	_content.position = Vector2(
		(size.x - DESIGN_W * s) / 2.0,
		(size.y - DESIGN_H * s) / 2.0
	)


func connect_session(s: GameSession) -> void:
	session = s
	session.state_updated.connect(_on_state_updated)
	session.actions_received.connect(_on_actions_received)
	session.game_over.connect(_on_game_over)

	# 現在の状態で初回描画
	var cs: ClientState = session.get_client_state()
	if cs != null:
		_refresh(cs)


func disconnect_session() -> void:
	if session != null:
		if session.state_updated.is_connected(_on_state_updated):
			session.state_updated.disconnect(_on_state_updated)
		if session.actions_received.is_connected(_on_actions_received):
			session.actions_received.disconnect(_on_actions_received)
		if session.game_over.is_connected(_on_game_over):
			session.game_over.disconnect(_on_game_over)
		session = null


func _on_state_updated(client_state: ClientState, _events: Array) -> void:
	_refresh(client_state)


func _on_game_over(_winner: int) -> void:
	pass


func _refresh(cs: ClientState) -> void:
	_clear_interaction_state()
	_top_bar.update_display(cs)
	_field_layout.update_layout(cs)
	_card_layer.sync_state(cs, _field_layout)
	_my_hand.sync_cards(cs.my_hand, true)
	_opp_hand.sync_hidden(cs.opponent_hand_count)


# ---------------------------------------------------------------------------
# アクション・選択
# ---------------------------------------------------------------------------

func _on_actions_received(actions: Array) -> void:
	_current_actions = actions
	var has_play_card: bool = false
	var has_field_action: bool = false
	for a in actions:
		var atype: int = a.get("type", -1)
		if atype == Enums.ActionType.PLAY_CARD:
			has_play_card = true
		elif atype == Enums.ActionType.OPEN or atype == Enums.ActionType.ACTIVATE_SKILL:
			has_field_action = true

	_my_hand.is_selectable = has_play_card

	if has_field_action:
		_show_action_phase_buttons()
		_btn_pass.visible = true
	elif not has_play_card:
		_btn_pass.visible = true


func _show_action_phase_buttons() -> void:
	_clear_action_buttons()
	var cs: ClientState = session.get_client_state()
	if cs == null:
		return

	for a in _current_actions:
		var atype: int = a.get("type", -1)
		if atype != Enums.ActionType.OPEN and atype != Enums.ActionType.ACTIVATE_SKILL:
			continue
		var iid: int = a.get("instance_id", -1)
		var rect: Rect2 = _find_field_card_rect(iid, cs)
		if rect.size == Vector2.ZERO:
			continue
		var label: String = "オープン" if atype == Enums.ActionType.OPEN else "スキル発動"
		var btn: Button = _make_overlay_button(label, rect)
		btn.visible = true
		var action_copy: Dictionary = a.duplicate()
		btn.pressed.connect(func() -> void: _on_action_button_pressed(action_copy))
		_overlay.add_child(btn)
		_action_buttons.append(btn)


func _find_field_card_rect(instance_id: int, cs: ClientState) -> Rect2:
	# 自分のステージを検索
	for i in range(cs.stages[cs.my_player].size()):
		var card: Dictionary = cs.stages[cs.my_player][i]
		if card.get("instance_id") == instance_id:
			var pos: Vector2 = _field_layout.get_stage_slot_pos(cs.my_player, i)
			return Rect2(pos, Vector2(300, 420))
	# 自分の楽屋を検索
	if cs.backstages[cs.my_player] != null:
		var bs: Dictionary = cs.backstages[cs.my_player]
		if bs.get("instance_id") == instance_id:
			var pos: Vector2 = _field_layout.get_backstage_slot_pos(cs.my_player)
			return Rect2(pos, Vector2(300, 420))
	return Rect2(Vector2.ZERO, Vector2.ZERO)


func _on_action_button_pressed(action: Dictionary) -> void:
	if session == null:
		return
	_clear_interaction_state()
	session.send_action(action)


func _clear_action_buttons() -> void:
	for btn in _action_buttons:
		btn.queue_free()
	_action_buttons.clear()


func _on_hand_card_clicked(instance_id: int) -> void:
	if not _my_hand.is_selectable:
		return
	if _selected_instance_id == instance_id:
		# 同じカード再クリック → 選択解除
		_selected_instance_id = -1
		_my_hand.deselect()
		_hide_target_buttons()
	else:
		# 新規 or 別カード選択
		_selected_instance_id = instance_id
		var idx: int = _my_hand.find_card_index(instance_id)
		_my_hand.select_card(idx)
		_show_target_buttons(instance_id)


func _show_target_buttons(instance_id: int) -> void:
	var can_stage: bool = false
	var can_backstage: bool = false
	for a in _current_actions:
		if a.get("type") != Enums.ActionType.PLAY_CARD:
			continue
		if a.get("instance_id") != instance_id:
			continue
		var target: String = a.get("target", "")
		if target == "stage":
			can_stage = true
		elif target == "backstage":
			can_backstage = true
	_btn_stage.visible = can_stage
	_btn_backstage.visible = can_backstage


func _hide_target_buttons() -> void:
	_btn_stage.visible = false
	_btn_backstage.visible = false


func _on_stage_pressed() -> void:
	if session == null or _selected_instance_id < 0:
		return
	var iid: int = _selected_instance_id
	_clear_interaction_state()
	session.send_action({
		"type": Enums.ActionType.PLAY_CARD,
		"instance_id": iid,
		"target": "stage",
	})


func _on_backstage_pressed() -> void:
	if session == null or _selected_instance_id < 0:
		return
	var iid: int = _selected_instance_id
	_clear_interaction_state()
	session.send_action({
		"type": Enums.ActionType.PLAY_CARD,
		"instance_id": iid,
		"target": "backstage",
	})


func _on_pass_pressed() -> void:
	if session == null:
		return
	_clear_interaction_state()
	session.send_action({"type": Enums.ActionType.PASS})


func _clear_interaction_state() -> void:
	_current_actions = []
	_selected_instance_id = -1
	_my_hand.is_selectable = false
	_my_hand.deselect()
	_clear_action_buttons()
	if _btn_stage != null:
		_btn_stage.visible = false
	if _btn_backstage != null:
		_btn_backstage.visible = false
	if _btn_pass != null:
		_btn_pass.visible = false

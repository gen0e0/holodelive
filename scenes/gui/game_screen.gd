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
const _GameStartBannerScene: PackedScene = preload("res://scenes/gui/animation/game_start_banner.tscn")

var session: GameSession

var _current_actions: Array = []
var _selected_instance_id: int = -1
var _waiting_choice: bool = false
var _choice_data: Dictionary = {}
var _director: StagingDirector

@onready var _content: Control = $Content
@onready var _top_bar: TopBar = $Content/TopBar
@onready var _field_layout: FieldLayout = $Content/FieldLayout
@onready var _card_layer: CardLayer = $Content/CardLayer
@onready var _deck_view: DeckView = $Content/DeckView
@onready var _home_view: HomeView = $Content/HomeView
@onready var _my_hand: HandZone = $Content/MyHandZone
@onready var _opp_hand: HandZone = $Content/OppHandZone
@onready var _anim_layer: Control = $Content/AnimationLayer
@onready var _card_tooltip: CardTooltip = $Content/CardTooltip

var _overlay: Control
var _btn_stage: OverlayButton
var _btn_backstage: OverlayButton
var _btn_pass: OverlayButton
var _action_buttons: Array = []  # ACTION フェーズ用の動的ボタン
var _my_rank_label: RankLabel
var _opp_rank_label: RankLabel


func _ready() -> void:
	_director = StagingDirector.new(_anim_layer)
	_director.hand = _my_hand
	_director.opp_hand = _opp_hand
	_director.card_layer = _card_layer
	_director.deck_view = _deck_view
	_director.home_view = _home_view
	_director.field_layout = _field_layout
	_director.refresh_fn = _refresh
	_director.on_actions_ready = _handle_actions_received
	_my_hand.card_clicked.connect(_on_hand_card_clicked)
	_my_hand.card_hovered.connect(_on_card_hovered)
	_my_hand.card_unhovered.connect(_on_card_unhovered)
	_card_layer.card_hovered.connect(_on_card_hovered)
	_card_layer.card_unhovered.connect(_on_card_unhovered)
	_home_view.card_clicked.connect(_on_home_card_clicked)
	_home_view.card_hovered.connect(_on_card_hovered)
	_home_view.card_unhovered.connect(_on_card_unhovered)
	_setup_buttons()
	_setup_rank_labels()


func _setup_rank_labels() -> void:
	_my_rank_label = RankLabel.new()
	_my_rank_label.position = Vector2(376, 44)
	_content.add_child(_my_rank_label)

	_opp_rank_label = RankLabel.new()
	_opp_rank_label.position = Vector2(1264, 44)
	_content.add_child(_opp_rank_label)


func _setup_buttons() -> void:
	_overlay = Control.new()
	_overlay.z_index = 100
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_overlay)

	# ステージ全体を覆うボタン (MyStage1-3: x=24-948, y=80-500)
	_btn_stage = OverlayButton.create("ステージにプレイ", Rect2(24, 80, 924, 420))
	_btn_stage.pressed.connect(_on_stage_pressed)
	_overlay.add_child(_btn_stage)

	# 楽屋全体を覆うボタン (MyBackstage: x=648-948, y=530-950)
	_btn_backstage = OverlayButton.create("楽屋にプレイ", Rect2(648, 530, 300, 420))
	_btn_backstage.pressed.connect(_on_backstage_pressed)
	_overlay.add_child(_btn_backstage)

	# パスボタン（カードが出せない時のみ表示）
	_btn_pass = OverlayButton.create("パス", Rect2(360, 430, 200, 60))
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
	session.choice_requested.connect(_on_choice_requested)
	session.game_started.connect(_on_game_started)
	session.game_over.connect(_on_game_over)

	# 現在の状態で初回描画
	var cs: ClientState = session.get_client_state()
	if cs != null:
		_director.initialize(cs)


func disconnect_session() -> void:
	if session != null:
		if session.state_updated.is_connected(_on_state_updated):
			session.state_updated.disconnect(_on_state_updated)
		if session.actions_received.is_connected(_on_actions_received):
			session.actions_received.disconnect(_on_actions_received)
		if session.choice_requested.is_connected(_on_choice_requested):
			session.choice_requested.disconnect(_on_choice_requested)
		if session.game_started.is_connected(_on_game_started):
			session.game_started.disconnect(_on_game_started)
		if session.game_over.is_connected(_on_game_over):
			session.game_over.disconnect(_on_game_over)
		session = null
	_director.cancel_all()
	_clear_interaction_state()


func _on_state_updated(client_state: ClientState, events: Array) -> void:
	_director.enqueue_state_update(client_state, events)


func _on_game_started() -> void:
	_director.enqueue_banner(_GameStartBannerScene)


func _on_game_over(_winner: int) -> void:
	pass


# ---------------------------------------------------------------------------
# カードツールチップ
# ---------------------------------------------------------------------------

func _on_card_hovered(card_data: Dictionary, card_global_rect: Rect2) -> void:
	var local_pos: Vector2 = _content.get_global_transform().affine_inverse() * card_global_rect.position
	var local_size: Vector2 = card_global_rect.size / _content.scale
	_card_tooltip.show_tooltip(card_data, Rect2(local_pos, local_size))


func _on_card_unhovered() -> void:
	_card_tooltip.hide_tooltip()


func _refresh(cs: ClientState) -> void:
	_clear_interaction_state()
	_top_bar.update_display(cs)
	_field_layout.update_layout(cs)
	_card_layer.sync_state(cs, _field_layout)
	_deck_view.update_count(cs.deck_count)
	_home_view.update_cards(cs.home)
	_my_hand.sync_cards(cs.my_hand, true)
	_opp_hand.sync_hidden(cs.opponent_hand_count)
	_update_rank_labels(cs)


func _update_rank_labels(cs: ClientState) -> void:
	var my_p: int = cs.my_player
	var opp_p: int = 1 - my_p
	var my_rank: Enums.ShowdownRank = _my_rank_label.update_rank(cs.stages[my_p], cs.backstages[my_p])
	var opp_rank: Enums.ShowdownRank = _opp_rank_label.update_rank(cs.stages[opp_p], cs.backstages[opp_p])
	# 値が小さいほど強い。同値なら両方明るく表示
	_my_rank_label.set_superior(my_rank <= opp_rank)
	_opp_rank_label.set_superior(opp_rank <= my_rank)


# ---------------------------------------------------------------------------
# アクション・選択
# ---------------------------------------------------------------------------

func _on_actions_received(actions: Array) -> void:
	_director.enqueue_actions(actions)


func _handle_actions_received(actions: Array) -> void:
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
		var btn: OverlayButton = OverlayButton.create(label, rect)
		btn.visible = true
		var action_copy: Dictionary = a.duplicate()
		btn.pressed.connect(func() -> void: _on_action_button_pressed(action_copy))
		_overlay.add_child(btn)
		_action_buttons.append(btn)


func _find_field_card_rect(instance_id: int, _cs: ClientState) -> Rect2:
	var xform: Dictionary = _card_layer.get_card_content_transform(instance_id)
	if xform.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var full_size := Vector2(300, 420)
	var s: Vector2 = xform.get("scale", Vector2.ONE)
	var card_size: Vector2 = full_size * s.x
	var offset: Vector2 = (full_size - card_size) / 2.0
	return Rect2(xform.get("pos", Vector2.ZERO) + offset, card_size)


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
	_waiting_choice = false
	_choice_data = {}
	_my_hand.is_selectable = false
	_my_hand.deselect()
	_clear_action_buttons()
	_home_view.dismiss_popup()
	if _btn_stage != null:
		_btn_stage.visible = false
	if _btn_backstage != null:
		_btn_backstage.visible = false
	if _btn_pass != null:
		_btn_pass.visible = false


# ---------------------------------------------------------------------------
# PendingChoice 処理
# ---------------------------------------------------------------------------

func _on_choice_requested(choice_data: Dictionary) -> void:
	_waiting_choice = true
	_choice_data = choice_data
	var choice_type: int = choice_data.get("choice_type", -1)
	if choice_type == Enums.ChoiceType.SELECT_CARD:
		var valid_targets: Array = choice_data.get("valid_targets", [])
		var cs: ClientState = session.get_client_state()
		if cs == null:
			return
		var home_ids: Array = []
		for card in cs.home:
			home_ids.append(card.get("instance_id", -1))
		var home_targets: Array = []
		for tid in valid_targets:
			if home_ids.has(tid):
				home_targets.append(tid)
		if not home_targets.is_empty():
			_home_view.set_selectable(home_targets)
			_home_view.open_popup()


func _on_home_card_clicked(instance_id: int) -> void:
	if _waiting_choice:
		var valid_targets: Array = _choice_data.get("valid_targets", [])
		if valid_targets.has(instance_id):
			var choice_index: int = _choice_data.get("choice_index", 0)
			_clear_interaction_state()
			session.send_choice(choice_index, instance_id)
			return

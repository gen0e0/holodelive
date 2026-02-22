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

@onready var _content: Control = $Content
@onready var _top_bar: TopBar = $Content/TopBar
@onready var _field_layout: FieldLayout = $Content/FieldLayout
@onready var _card_layer: CardLayer = $Content/CardLayer
@onready var _my_hand: HandZone = $Content/MyHandZone
@onready var _opp_hand: HandZone = $Content/OppHandZone


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
	session.game_over.connect(_on_game_over)

	# 現在の状態で初回描画
	var cs: ClientState = session.get_client_state()
	if cs != null:
		_refresh(cs)


func disconnect_session() -> void:
	if session != null:
		if session.state_updated.is_connected(_on_state_updated):
			session.state_updated.disconnect(_on_state_updated)
		if session.game_over.is_connected(_on_game_over):
			session.game_over.disconnect(_on_game_over)
		session = null


func _on_state_updated(client_state: ClientState, _events: Array) -> void:
	_refresh(client_state)


func _on_game_over(_winner: int) -> void:
	pass


func _refresh(cs: ClientState) -> void:
	_top_bar.update_display(cs)
	_field_layout.update_layout(cs)
	_card_layer.sync_state(cs, _field_layout)
	_my_hand.sync_cards(cs.my_hand, true)
	_opp_hand.sync_hidden(cs.opponent_hand_count)

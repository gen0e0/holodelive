class_name GameScreen
extends Control

## GUI ルートコンポーネント。
## GameSession のシグナルを受けて TopBar / FieldLayout / CardLayer を更新する。
## 内部は 1920x1080 固定座標で描画し、親サイズに合わせてスケーリングする。

const DESIGN_W: float = 1920.0
const DESIGN_H: float = 1080.0

var session: GameSession

var _content: Control
var _top_bar: TopBar
var _field_layout: FieldLayout
var _card_layer: CardLayer
var _bg: ColorRect


func _init() -> void:
	clip_contents = true

	# 1920x1080 固定サイズのコンテンツコンテナ
	_content = Control.new()
	_content.size = Vector2(DESIGN_W, DESIGN_H)
	add_child(_content)

	# 背景
	_bg = ColorRect.new()
	_bg.color = Color(0.12, 0.12, 0.16)
	_bg.size = Vector2(DESIGN_W, DESIGN_H)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_bg)

	# TopBar
	_top_bar = TopBar.new()
	_top_bar.position = Vector2(0, 4)
	_top_bar.size = Vector2(DESIGN_W, 32)
	_content.add_child(_top_bar)

	# FieldLayout (SlotMarker 配置)
	_field_layout = FieldLayout.new()
	_content.add_child(_field_layout)

	# CardLayer (CardView 管理)
	_card_layer = CardLayer.new()
	_content.add_child(_card_layer)


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

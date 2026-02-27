class_name HomeView
extends Control

## 自宅（ホーム）表示コンポーネント。最上部カードを表向きで表示する。
## クリックでポップアップを開き、全カードを閲覧・選択できる。

signal card_clicked(instance_id: int)
signal card_hovered(card_data: Dictionary, global_rect: Rect2)
signal card_unhovered()

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const CARD_SCALE: float = 0.5
const STACK_OFFSET_X: float = 4.0  # カード1枚あたりの右方向ずらし量
const POPUP_CARD_W: float = 150.0
const POPUP_CARD_H: float = 210.0
const POPUP_PADDING: float = 12.0
const POPUP_GAP: float = 8.0

var _card_view: CardView
var _cards: Array = []
var _popup_container: Control
var _popup_panel: Panel
var _popup_triangle: Control
var _card_container: HBoxContainer
var _popup_card_views: Array = []
var _popup_open: bool = false
var _selectable_ids: Array = []
var _highlight_panels: Dictionary = {}
var _popup_tween: Tween = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP

	_card_view = _CardViewScene.instantiate()
	_card_view.managed_hover = true
	_card_view.scale = Vector2(CARD_SCALE, CARD_SCALE)
	_card_view.position = -_card_view.pivot_offset * (1.0 - CARD_SCALE)
	_card_view.card_clicked.connect(func(_id: int) -> void: toggle_popup())
	add_child(_card_view)

	_build_popup()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_popup()
		accept_event()


func get_card_content_transform() -> Dictionary:
	return {
		"pos": position + _card_view.position,
		"scale": _card_view.scale,
		"rotation": 0.0,
	}


func update_cards(cards: Array) -> void:
	_cards = cards
	if cards.size() > 0:
		var top: Dictionary = cards[cards.size() - 1]
		_card_view.setup(top, true)
		_card_view.visible = true
		# カード枚数に応じて右にずらす（最上部カードが一番右）
		var base_x: float = -_card_view.pivot_offset.x * (1.0 - CARD_SCALE)
		_card_view.position.x = base_x + (cards.size() - 1) * STACK_OFFSET_X
	else:
		_card_view.visible = false
	if _popup_open:
		_populate_popup()
		_layout_popup()


func get_cards() -> Array:
	return _cards


# ---------------------------------------------------------------------------
# ポップアップ構築
# ---------------------------------------------------------------------------

func _build_popup() -> void:
	_popup_container = Control.new()
	_popup_container.z_index = 30
	_popup_container.visible = false
	_popup_container.modulate.a = 0.0
	_popup_container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popup_container)

	_popup_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 0.8)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_popup_panel.add_theme_stylebox_override("panel", style)
	_popup_panel.mouse_filter = MOUSE_FILTER_STOP
	_popup_container.add_child(_popup_panel)

	_popup_triangle = Control.new()
	_popup_triangle.custom_minimum_size = Vector2(20, 12)
	_popup_triangle.draw.connect(_draw_triangle)
	_popup_container.add_child(_popup_triangle)

	_card_container = HBoxContainer.new()
	_card_container.add_theme_constant_override("separation", int(POPUP_GAP))
	_popup_panel.add_child(_card_container)


func _draw_triangle() -> void:
	var w: float = _popup_triangle.size.x
	var h: float = _popup_triangle.size.y
	var points := PackedVector2Array([
		Vector2(0, 0),
		Vector2(w, 0),
		Vector2(w / 2.0, h),
	])
	_popup_triangle.draw_colored_polygon(points, Color(0.15, 0.15, 0.22, 0.95))


# ---------------------------------------------------------------------------
# カード配置
# ---------------------------------------------------------------------------

func _populate_popup() -> void:
	# 既存のカードビューをクリア
	for cv in _popup_card_views:
		cv.queue_free()
	_popup_card_views.clear()
	_highlight_panels.clear()

	for card_data in _cards:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(POPUP_CARD_W, POPUP_CARD_H)
		wrapper.mouse_filter = MOUSE_FILTER_IGNORE

		# ハイライトパネル（選択可能カード用）
		var highlight := Panel.new()
		var hl_style := StyleBoxFlat.new()
		hl_style.bg_color = Color(0, 0, 0, 0)
		hl_style.border_color = Color(1.0, 0.85, 0.2, 1.0)  # 金色
		hl_style.border_width_bottom = 3
		hl_style.border_width_top = 3
		hl_style.border_width_left = 3
		hl_style.border_width_right = 3
		hl_style.corner_radius_top_left = 6
		hl_style.corner_radius_top_right = 6
		hl_style.corner_radius_bottom_left = 6
		hl_style.corner_radius_bottom_right = 6
		highlight.add_theme_stylebox_override("panel", hl_style)
		highlight.position = Vector2(-3, -3)
		highlight.size = Vector2(POPUP_CARD_W + 6, POPUP_CARD_H + 6)
		highlight.mouse_filter = MOUSE_FILTER_IGNORE
		var iid: int = card_data.get("instance_id", -1)
		highlight.visible = _selectable_ids.has(iid)
		wrapper.add_child(highlight)
		_highlight_panels[iid] = highlight

		# CardView
		var cv: CardView = _CardViewScene.instantiate()
		cv.managed_hover = true
		cv.scale = Vector2(CARD_SCALE, CARD_SCALE)
		cv.position = -cv.pivot_offset * (1.0 - CARD_SCALE)
		cv.setup(card_data, true)
		var card_iid: int = iid
		cv.card_clicked.connect(func(_id: int) -> void: card_clicked.emit(card_iid))
		cv.card_hovered.connect(func(cd: Dictionary, gr: Rect2) -> void: card_hovered.emit(cd, gr))
		cv.card_unhovered.connect(func() -> void: card_unhovered.emit())
		wrapper.add_child(cv)

		_card_container.add_child(wrapper)
		_popup_card_views.append(wrapper)


func _layout_popup() -> void:
	var count: int = _cards.size()
	if count == 0:
		return

	var panel_w: float = count * POPUP_CARD_W + (count - 1) * POPUP_GAP + POPUP_PADDING * 2
	var panel_h: float = POPUP_CARD_H + POPUP_PADDING * 2

	_popup_panel.size = Vector2(panel_w, panel_h)
	_card_container.position = Vector2(POPUP_PADDING, POPUP_PADDING)
	_card_container.size = Vector2(panel_w - POPUP_PADDING * 2, POPUP_CARD_H)

	# パネル下端 + 三角形が HomeView 上辺 (y=0) に接するよう配置
	var triangle_h: float = 12.0
	_popup_container.position = Vector2(0, 0)
	_popup_panel.position = Vector2(0, -(panel_h + triangle_h))

	# 三角形は HomeView の中心 x に配置
	var home_center_x: float = size.x / 2.0
	_popup_triangle.position = Vector2(home_center_x - 10, -triangle_h)
	_popup_triangle.size = Vector2(20, triangle_h)
	_popup_triangle.queue_redraw()


# ---------------------------------------------------------------------------
# アニメーション
# ---------------------------------------------------------------------------

func open_popup() -> void:
	if _cards.is_empty():
		return
	if _popup_open:
		return
	_popup_open = true
	_populate_popup()
	_layout_popup()

	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()

	var target_y: float = _popup_container.position.y
	_popup_container.visible = true
	_popup_container.modulate.a = 0.0
	_popup_container.position.y = target_y + 20.0

	_popup_tween = create_tween().set_parallel(true)
	_popup_tween.tween_property(_popup_container, "modulate:a", 1.0, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_popup_container, "position:y", target_y, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close_popup() -> void:
	if not _popup_open:
		return
	_popup_open = false

	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()

	var start_y: float = _popup_container.position.y
	_popup_tween = create_tween().set_parallel(true)
	_popup_tween.tween_property(_popup_container, "modulate:a", 0.0, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_popup_container, "position:y", start_y + 20.0, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_popup_tween.chain().tween_callback(func() -> void:
		_popup_container.visible = false
	)


func toggle_popup() -> void:
	if _popup_open:
		close_popup()
	else:
		open_popup()


# ---------------------------------------------------------------------------
# 選択モード API
# ---------------------------------------------------------------------------

func set_selectable(ids: Array) -> void:
	_selectable_ids = ids
	_update_highlights()


func clear_selectable() -> void:
	_selectable_ids = []
	_update_highlights()


func dismiss_popup() -> void:
	close_popup()
	clear_selectable()


func _update_highlights() -> void:
	for iid in _highlight_panels:
		var panel: Panel = _highlight_panels[iid]
		if is_instance_valid(panel):
			panel.visible = _selectable_ids.has(iid)

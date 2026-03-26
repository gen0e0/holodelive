class_name DeckReorderSelector
extends ChoiceHandler

## デッキ並べ替えUI: デッキ上から最大3枚を3つのスロットに表示し、
## 入れ替えボタンで並べ替えて決定する。
##
## スロット1（上）= デッキトップ（次にドローされるカード）
## スロット2（中）= デッキ2番目
## スロット3（下）= デッキ3番目
##
## スキル発動時にカードが自動でスロットに飛んでくる。
## 入替ボタン（1↔2, 2↔3）で隣接カードをスワップ。決定ボタンで送信。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")

const SLOT_SCALE := Vector2(0.7, 0.7)
const CARD_PIVOT := Vector2(150, 210)
const PIVOT_OFFSET := Vector2(150 * 0.3, 210 * 0.3)
const SLOT_W: float = 300 * 0.7   # 210
const SLOT_H: float = 420 * 0.7   # 294

## スロット位置（フレーム）
const SLOT_X: float = 210
const SLOT_1_Y: float = 10
const SLOT_2_Y: float = 360
const SLOT_3_Y: float = 710

const FLY_DURATION: float = 0.25

var _ui_parent: Control
var _deck_position: Vector2  # Content 座標系でのデッキ中央位置

var _slot_iids: Array = [-1, -1, -1]
var _slot_cvs: Array = [null, null, null]
var _slot_positions: Array = []  # Vector2[] — カード位置（ピボット補正済み）
var _frame_positions: Array = [] # Vector2[] — フレーム位置

var _choice_index: int = 0
var _active: bool = false
var _animating: bool = false
var _card_data_map: Dictionary = {}

var _frames: Array = []         # Panel[]
var _labels: Array = []         # Label[]
var _swap_buttons: Array = []   # OverlayButton[] (2個: 1↔2, 2↔3)
var _confirm_button: OverlayButton = null


func _init(ui_parent: Control, deck_view: DeckView) -> void:
	_ui_parent = ui_parent
	# DeckView の Content 内位置をスロットスケール基準で補正
	# DeckView: scale=0.5, pivot=CardView.pivot_offset(150,210)
	# スロット側: scale=0.7, ピボット補正=PIVOT_OFFSET
	_deck_position = deck_view.position - PIVOT_OFFSET
	_frame_positions = [
		Vector2(SLOT_X, SLOT_1_Y),
		Vector2(SLOT_X, SLOT_2_Y),
		Vector2(SLOT_X, SLOT_3_Y),
	]
	_slot_positions = [
		Vector2(SLOT_X - PIVOT_OFFSET.x, SLOT_1_Y - PIVOT_OFFSET.y),
		Vector2(SLOT_X - PIVOT_OFFSET.x, SLOT_2_Y - PIVOT_OFFSET.y),
		Vector2(SLOT_X - PIVOT_OFFSET.x, SLOT_3_Y - PIVOT_OFFSET.y),
	]


func can_handle(choice_data: Dictionary) -> bool:
	return (choice_data.get("choice_type", -1) == Enums.ChoiceType.SELECT_CARD
		and choice_data.get("ui_hint", "") == "deck_reorder")


func activate(choice_data: Dictionary) -> void:
	_choice_index = choice_data.get("choice_index", 0)
	_slot_iids = [-1, -1, -1]
	_slot_cvs = [null, null, null]
	_animating = true

	# カードデータマッピング構築
	_card_data_map = {}
	var targets: Array = choice_data.get("valid_targets", [])
	var details: Array = choice_data.get("valid_target_details", [])
	for i in range(targets.size()):
		if i < details.size():
			_card_data_map[targets[i]] = details[i]

	var count: int = targets.size()

	# スロットフレーム + ラベル（使用枚数分のみ）
	var label_texts: Array = ["デッキ上", "2番目", "3番目"]
	for i in range(count):
		var frame: Panel = _create_slot_frame(_frame_positions[i])
		_ui_parent.add_child(frame)
		_frames.append(frame)
		var lbl: Label = _create_label(label_texts[i],
			Vector2(_frame_positions[i].x, _frame_positions[i].y - 28))
		_ui_parent.add_child(lbl)
		_labels.append(lbl)

	# 入替ボタン（隣接スロット間）
	for i in range(count - 1):
		var mid_y: float = (_frame_positions[i].y + SLOT_H + _frame_positions[i + 1].y) / 2.0 - 20
		var btn_x: float = SLOT_X + SLOT_W / 2.0 - 50
		var btn: OverlayButton = OverlayButton.create("入替", Rect2(btn_x, mid_y, 100, 40))
		btn.visible = true
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_swap_pressed(idx))
		_ui_parent.add_child(btn)
		_swap_buttons.append(btn)

	# 決定ボタン
	var btn_x: float = SLOT_X + SLOT_W + 30
	var btn_y: float = _frame_positions[0].y + (SLOT_H * count + (count - 1) * 16) / 2.0 - 30
	_confirm_button = OverlayButton.create("決定", Rect2(btn_x, btn_y, 140, 60))
	_confirm_button.visible = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_ui_parent.add_child(_confirm_button)

	_active = true

	# デッキからスロットへカードを飛ばすアニメーション
	# デッキ位置（画面右端）から各スロットへ
	var deck_pos: Vector2 = _deck_position
	for i in range(count):
		_slot_iids[i] = targets[i]
		var cv: CardView = _create_card_view(targets[i])
		cv.position = deck_pos
		cv.scale = SLOT_SCALE
		_ui_parent.add_child(cv)
		_slot_cvs[i] = cv

		var tw: Tween = cv.create_tween()
		tw.tween_property(cv, "position", _slot_positions[i], FLY_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
			.set_delay(i * 0.1)
		if i == count - 1:
			tw.finished.connect(func() -> void: _animating = false)


func deactivate() -> void:
	if not _active:
		return
	_active = false

	for cv in _slot_cvs:
		if cv != null:
			cv.queue_free()
	_slot_cvs = [null, null, null]
	_slot_iids = [-1, -1, -1]

	for node in _frames:
		if node != null:
			node.queue_free()
	_frames = []
	for node in _labels:
		if node != null:
			node.queue_free()
	_labels = []
	for node in _swap_buttons:
		if node != null:
			node.queue_free()
	_swap_buttons = []
	if _confirm_button != null:
		_confirm_button.queue_free()
		_confirm_button = null
	_card_data_map = {}


# ---------------------------------------------------------------------------
# 入替
# ---------------------------------------------------------------------------

func _on_swap_pressed(idx: int) -> void:
	if not _active or _animating:
		return
	var a: int = idx
	var b: int = idx + 1
	if _slot_iids[a] < 0 or _slot_iids[b] < 0:
		return

	_animating = true

	# ID 入替
	var tmp_iid: int = _slot_iids[a]
	_slot_iids[a] = _slot_iids[b]
	_slot_iids[b] = tmp_iid

	# CardView 入替
	var tmp_cv: CardView = _slot_cvs[a]
	_slot_cvs[a] = _slot_cvs[b]
	_slot_cvs[b] = tmp_cv

	# アニメーション
	_tween_card(_slot_cvs[a], _slot_positions[a])
	var tw: Tween = _tween_card(_slot_cvs[b], _slot_positions[b])
	tw.finished.connect(func() -> void: _animating = false)


# ---------------------------------------------------------------------------
# 決定
# ---------------------------------------------------------------------------

func _on_confirm_pressed() -> void:
	if not _active or _animating:
		return
	var result: Array = []
	for iid in _slot_iids:
		if iid >= 0:
			result.append(iid)
	if result.is_empty():
		return
	_animating = true

	# スロット→デッキへ戻すアニメーション（下から順に）
	var deck_pos: Vector2 = _deck_position
	var count: int = result.size()
	var last_tw: Tween = null
	for i in range(count - 1, -1, -1):
		var cv: CardView = _slot_cvs[i]
		if cv == null:
			continue
		# デッキに戻すので裏向きにする
		cv.setup(cv._card_data, false)
		var tw: Tween = cv.create_tween()
		tw.tween_property(cv, "position", deck_pos, FLY_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) \
			.set_delay((count - 1 - i) * 0.1)
		last_tw = tw
	if last_tw != null:
		var r: Array = result.duplicate()
		last_tw.finished.connect(func() -> void: resolved.emit(_choice_index, r))
	else:
		resolved.emit(_choice_index, result)


# ---------------------------------------------------------------------------
# UI ヘルパー
# ---------------------------------------------------------------------------

func _create_card_view(iid: int) -> CardView:
	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_data: Dictionary = _card_data_map.get(iid, {})
	cv.setup(card_data, true)
	return cv


func _tween_card(cv: CardView, to_pos: Vector2) -> Tween:
	var tw: Tween = cv.create_tween()
	tw.tween_property(cv, "position", to_pos, FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


func _create_slot_frame(pos: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(SLOT_W, SLOT_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.15)
	style.border_color = Color(0.4, 0.6, 0.9, 0.5)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_label(text: String, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.8))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

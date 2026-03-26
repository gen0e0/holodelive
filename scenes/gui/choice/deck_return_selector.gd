class_name DeckReturnSelector
extends ChoiceHandler

## デッキ戻しUI: 手札から2枚を選び、デッキトップの順番を指定する。
##
## スロットA（上）= デッキトップ（次にドローされるカード）
## スロットB（下）= デッキ2番目
##
## 手札クリック → Aに入る。Aにあったカードは B へ押し出し、B にあったカードは手札へ戻る。
## 入替ボタンで A↔B をスワップ。決定ボタンで [A, B] を送信。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")

const SLOT_SCALE := Vector2(0.7, 0.7)
const CARD_PIVOT := Vector2(150, 210)  # CardView の pivot_offset
## スケール時のピボット補正: CardView の position をこの分だけずらす
const PIVOT_OFFSET := Vector2(150 * 0.3, 210 * 0.3)  # pivot * (1 - scale)
const SLOT_A_POS := Vector2(210, 120)       # フレーム位置
const SLOT_B_POS := Vector2(210, 440)       # フレーム位置
const CARD_A_POS := Vector2(210 - 150 * 0.3, 120 - 210 * 0.3)  # ピボット補正済み
const CARD_B_POS := Vector2(210 - 150 * 0.3, 440 - 210 * 0.3)  # ピボット補正済み
const FLY_DURATION: float = 0.25

var _hand_zone: HandZone
var _get_client_state: Callable
var _ui_parent: Control

var _slot_a_iid: int = -1
var _slot_b_iid: int = -1
var _slot_a_cv: CardView = null
var _slot_b_cv: CardView = null

var _choice_index: int = 0
var _active: bool = false
var _animating: bool = false
var _card_data_map: Dictionary = {}  # iid -> card_data dict

var _frame_a: Panel = null
var _frame_b: Panel = null
var _label_a: Label = null
var _label_b: Label = null
var _swap_button: OverlayButton = null
var _confirm_button: OverlayButton = null


func _init(hand_zone: HandZone, get_cs: Callable, ui_parent: Control) -> void:
	_hand_zone = hand_zone
	_get_client_state = get_cs
	_ui_parent = ui_parent


func can_handle(choice_data: Dictionary) -> bool:
	return (choice_data.get("choice_type", -1) == Enums.ChoiceType.SELECT_CARD
		and choice_data.get("ui_hint", "") == "deck_return")


func activate(choice_data: Dictionary) -> void:
	_choice_index = choice_data.get("choice_index", 0)
	_slot_a_iid = -1
	_slot_b_iid = -1
	_animating = false

	# カードデータマッピング構築
	_card_data_map = {}
	var targets: Array = choice_data.get("valid_targets", [])
	var details: Array = choice_data.get("valid_target_details", [])
	for i in range(targets.size()):
		if i < details.size():
			_card_data_map[targets[i]] = details[i]

	# 手札を選択可能に
	_hand_zone.set_choice_selectable(targets)
	_hand_zone.card_clicked.connect(_on_hand_card_clicked)

	# スロットフレーム
	_frame_a = _create_slot_frame(SLOT_A_POS)
	_ui_parent.add_child(_frame_a)
	_frame_b = _create_slot_frame(SLOT_B_POS)
	_ui_parent.add_child(_frame_b)

	# ラベル
	_label_a = _create_label("デッキ上", Vector2(SLOT_A_POS.x, SLOT_A_POS.y - 28))
	_ui_parent.add_child(_label_a)
	_label_b = _create_label("2番目", Vector2(SLOT_B_POS.x, SLOT_B_POS.y - 28))
	_ui_parent.add_child(_label_b)

	# ボタン（スロット右隣に配置）
	var btn_x: float = SLOT_A_POS.x + 300 * SLOT_SCALE.x + 20
	_swap_button = OverlayButton.create("入替", Rect2(btn_x, 380, 120, 60))
	_swap_button.visible = false
	_swap_button.pressed.connect(_on_swap_pressed)
	_ui_parent.add_child(_swap_button)

	_confirm_button = OverlayButton.create("決定", Rect2(1440, 620, 220, 140))
	_confirm_button.add_theme_font_size_override("font_size", 36)
	_confirm_button.visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_ui_parent.add_child(_confirm_button)

	_active = true


func deactivate() -> void:
	if not _active:
		return
	_active = false

	# 手札に戻す
	if _slot_a_iid >= 0:
		_hand_zone.show_card(_slot_a_iid)
	if _slot_b_iid >= 0:
		_hand_zone.show_card(_slot_b_iid)
	_slot_a_iid = -1
	_slot_b_iid = -1

	# CardView 破棄
	if _slot_a_cv != null:
		_slot_a_cv.queue_free()
		_slot_a_cv = null
	if _slot_b_cv != null:
		_slot_b_cv.queue_free()
		_slot_b_cv = null

	# UI 破棄
	for node in [_frame_a, _frame_b, _label_a, _label_b, _swap_button, _confirm_button]:
		if node != null:
			node.queue_free()
	_frame_a = null
	_frame_b = null
	_label_a = null
	_label_b = null
	_swap_button = null
	_confirm_button = null

	# 手札状態リセット
	if _hand_zone.card_clicked.is_connected(_on_hand_card_clicked):
		_hand_zone.card_clicked.disconnect(_on_hand_card_clicked)
	_hand_zone.clear_choice_selectable()
	_hand_zone.clear_chosen()
	_card_data_map = {}


# ---------------------------------------------------------------------------
# クリック処理
# ---------------------------------------------------------------------------

func _on_hand_card_clicked(instance_id: int) -> void:
	if not _active or _animating:
		return
	if not _card_data_map.has(instance_id):
		return
	# 既にスロットにあるカードをクリック → 取り消し扱いはしない（手札は hide 済み）
	if instance_id == _slot_a_iid or instance_id == _slot_b_iid:
		return
	_place_card_in_a(instance_id)


func _place_card_in_a(new_iid: int) -> void:
	_animating = true

	# 現在の B を手札に戻す
	if _slot_b_iid >= 0:
		_return_slot_to_hand_immediate(_slot_b_iid, _slot_b_cv)
		_slot_b_iid = -1
		_slot_b_cv = null

	# 現在の A を B にスライド
	if _slot_a_iid >= 0:
		_slot_b_iid = _slot_a_iid
		_slot_b_cv = _slot_a_cv
		_slot_a_iid = -1
		_slot_a_cv = null
		_tween_card(_slot_b_cv, CARD_B_POS)

	# 新しいカードを A に飛行
	_hand_zone.hide_card(new_iid)
	_slot_a_iid = new_iid
	var from_xform: Dictionary = _hand_zone.get_card_content_transform(new_iid)
	_slot_a_cv = _create_card_view(new_iid)
	if not from_xform.is_empty():
		_slot_a_cv.position = from_xform.get("pos", CARD_A_POS)
		_slot_a_cv.scale = from_xform.get("scale", Vector2.ONE)
		_slot_a_cv.rotation = from_xform.get("rotation", 0.0)
	else:
		_slot_a_cv.position = CARD_A_POS
	_ui_parent.add_child(_slot_a_cv)

	var tw: Tween = _slot_a_cv.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_slot_a_cv, "position", CARD_A_POS, FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_slot_a_cv, "scale", SLOT_SCALE, FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_slot_a_cv, "rotation", 0.0, FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func() -> void: _animating = false)

	_update_buttons()


func _return_slot_to_hand_immediate(iid: int, cv: CardView) -> void:
	if cv != null:
		cv.queue_free()
	_hand_zone.show_card(iid)


# ---------------------------------------------------------------------------
# 入替
# ---------------------------------------------------------------------------

func _on_swap_pressed() -> void:
	if not _active or _animating:
		return
	if _slot_a_iid < 0 or _slot_b_iid < 0:
		return

	_animating = true

	# ID 入れ替え
	var tmp_iid: int = _slot_a_iid
	_slot_a_iid = _slot_b_iid
	_slot_b_iid = tmp_iid

	# CardView 入れ替え
	var tmp_cv: CardView = _slot_a_cv
	_slot_a_cv = _slot_b_cv
	_slot_b_cv = tmp_cv

	# アニメーション
	_tween_card(_slot_a_cv, CARD_A_POS)
	var tw: Tween = _tween_card(_slot_b_cv, CARD_B_POS)
	tw.finished.connect(func() -> void: _animating = false)


# ---------------------------------------------------------------------------
# 決定
# ---------------------------------------------------------------------------

func _on_confirm_pressed() -> void:
	if not _active or _animating:
		return
	if _slot_a_iid < 0 or _slot_b_iid < 0:
		return
	resolved.emit(_choice_index, [_slot_a_iid, _slot_b_iid])


# ---------------------------------------------------------------------------
# ボタン表示更新
# ---------------------------------------------------------------------------

func _update_buttons() -> void:
	var both_filled: bool = _slot_a_iid >= 0 and _slot_b_iid >= 0
	if _swap_button != null:
		_swap_button.visible = both_filled
	if _confirm_button != null:
		_confirm_button.visible = both_filled


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
	tw.set_parallel(true)
	tw.tween_property(cv, "position", to_pos, FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cv, "scale", SLOT_SCALE, FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cv, "rotation", 0.0, FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


func _create_slot_frame(pos: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(300 * SLOT_SCALE.x, 420 * SLOT_SCALE.y)
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

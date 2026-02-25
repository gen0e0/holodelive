class_name CardView
extends Control

signal card_clicked(instance_id: int)

## true の場合、組み込みホバー演出を無効化（HandZone など親が管理）
var managed_hover: bool = false

var instance_id: int = -1
var _face_up: bool = true
var _is_guest: bool = false
var _card_data: Dictionary = {}
var _hovered: bool = false
var _pressed: bool = false
var _click_tween: Tween = null
var _mask_tween: Tween = null

@onready var _card_body: Panel = $CardBody
@onready var _suit_panel: Panel = $CardBody/BgSuitPanel
@onready var _character_rect: TextureRect = $CardBody/CharacterRect
@onready var _name_label: Label = $CardBody/NameLabel
@onready var _info_label: Label = $CardBody/InfoLabel
@onready var _icon_container: HBoxContainer = $CardBody/IconContainer
var _guest_mask: Panel

const ICON_VIEW_SCENE: PackedScene = preload("res://scenes/gui/components/icon_view.tscn")

const PRESS_SCALE := Vector2(0.9, 0.9)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const OVERSHOOT_SCALE := Vector2(1.05, 1.05)
const PRESS_DURATION := 0.2
const OVERSHOOT_DURATION := 0.1
const SETTLE_DURATION := 0.15


## スートごとの背景色（キーは文字列: StateSerializer が String で格納するため）
static var SUIT_COLORS: Dictionary = {
	"LOVELY": Color(0.95, 0.5, 0.65),    # ピンク
	"COOL": Color(0.4, 0.55, 0.9),        # 青
	"HOT": Color(0.902, 0.855, 0.302, 1.0),         # 赤
	"ENGLISH": Color(0.65, 0.45, 0.85),   # 紫
	"INDONESIA": Color(0.35, 0.75, 0.45), # 緑
	"STAFF": Color(0.777, 0.777, 0.777, 1.0),        # 黄
}

const BACK_COLOR := Color(0.35, 0.35, 0.4)
const GUEST_LABEL_FONT_SIZE: int = 36
const MASK_FADE_DURATION := 0.2


func setup(card_data: Dictionary, face_up: bool) -> void:
	_card_data = card_data
	_is_guest = card_data.get("face_down", false)
	_face_up = true if _is_guest else face_up
	instance_id = card_data.get("instance_id", -1)
	# @onready 完了前に呼ばれた場合は _ready() で描画
	if is_node_ready():
		_update_display()


func _ready() -> void:
	# StyleBoxFlat を複製して各インスタンス固有にする
	var style: StyleBoxFlat = _suit_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		_suit_panel.add_theme_stylebox_override("panel", style.duplicate())
	_guest_mask = _create_guest_mask()
	add_child(_guest_mask)
	_update_display()


func _update_display() -> void:
	if _card_body == null:
		return

	if not _face_up or _card_data.get("hidden", false):
		_set_bg_color(BACK_COLOR)
		_character_rect.texture = null
		_name_label.text = "?"
		_info_label.text = ""
		_clear_icons()
		if _guest_mask:
			_guest_mask.visible = _is_guest
			_guest_mask.modulate.a = 1.0
		return

	# スートで背景色決定（suits は Array[String]: "LOVELY", "COOL" 等）
	var suits: Array = _card_data.get("suits", [])
	if suits.size() > 0:
		var first_suit: String = suits[0]
		_set_bg_color(SUIT_COLORS.get(first_suit, BACK_COLOR))
	else:
		_set_bg_color(BACK_COLOR)

	# キャラ画像
	var image_path: String = _card_data.get("image_path", "")
	if image_path != "" and ResourceLoader.exists(image_path):
		_character_rect.texture = load(image_path)
	else:
		_character_rect.texture = null

	# 名前
	var nickname: String = _card_data.get("nickname", "?")
	var card_id: int = _card_data.get("card_id", 0)
	_name_label.text = "#%03d\n%s" % [card_id, nickname]

	# アイコン画像
	_update_icons(_card_data.get("icons", []))

	# スート略称
	var suit_strs: Array[String] = []
	for su in suits:
		suit_strs.append(str(su).left(3))
	_info_label.text = ",".join(suit_strs)

	# ゲストマスク表示
	if _guest_mask:
		_guest_mask.visible = _is_guest
		_guest_mask.modulate.a = 1.0


func _clear_icons() -> void:
	for child in _icon_container.get_children():
		child.queue_free()


func _update_icons(icons: Array) -> void:
	_clear_icons()
	for ic in icons:
		var iv: IconView = ICON_VIEW_SCENE.instantiate()
		iv.icon_name = str(ic)
		_icon_container.add_child(iv)


func _set_bg_color(color: Color) -> void:
	var style: StyleBoxFlat = _suit_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = color


# -- クリックアニメーション --

func _animate_press() -> void:
	_kill_click_tween()
	_click_tween = create_tween()
	_click_tween.tween_property(_card_body, "scale", PRESS_SCALE, PRESS_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _animate_release() -> void:
	_kill_click_tween()
	_click_tween = create_tween()
	_click_tween.tween_property(_card_body, "scale", OVERSHOOT_SCALE, OVERSHOOT_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_click_tween.tween_property(_card_body, "scale", NORMAL_SCALE, SETTLE_DURATION) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


func _kill_click_tween() -> void:
	if _click_tween and _click_tween.is_valid():
		_click_tween.kill()
	_click_tween = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed = true
				_animate_press()
			else:
				if _pressed:
					_pressed = false
					_animate_release()
					card_clicked.emit(instance_id)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_EXIT:
			if _pressed:
				_pressed = false
				_animate_release()
			if not managed_hover:
				_hovered = false
				scale = Vector2(1.0, 1.0)
			if _is_guest and not _card_data.get("hidden", false):
				_fade_guest_mask(1.0)
		NOTIFICATION_MOUSE_ENTER:
			if not managed_hover:
				_hovered = true
				scale = Vector2(1.05, 1.05)
			if _is_guest and not _card_data.get("hidden", false):
				_fade_guest_mask(0.0)


# -- ゲストマスク --

func _fade_guest_mask(target_alpha: float) -> void:
	if _guest_mask == null:
		return
	if _mask_tween and _mask_tween.is_valid():
		_mask_tween.kill()
	_mask_tween = create_tween()
	_mask_tween.tween_property(_guest_mask, "modulate:a", target_alpha, MASK_FADE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _create_guest_mask() -> Panel:
	# 外枠パネル（CardBody と同じ角丸）
	var mask := Panel.new()
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.visible = false
	var mask_style := StyleBoxFlat.new()
	mask_style.corner_radius_top_left = 15
	mask_style.corner_radius_top_right = 15
	mask_style.corner_radius_bottom_left = 15
	mask_style.corner_radius_bottom_right = 15
	mask.add_theme_stylebox_override("panel", mask_style)

	# 白ボーダー（BgBorderPanel 相当）
	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(1, 1, 1, 1)
	border.add_theme_stylebox_override("panel", border_style)
	mask.add_child(border)

	# グレー背景（BgSuitPanel 相当）
	var suit := Panel.new()
	suit.set_anchors_preset(Control.PRESET_FULL_RECT)
	suit.offset_left = 10.0
	suit.offset_top = 10.0
	suit.offset_right = -10.0
	suit.offset_bottom = -10.0
	suit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var suit_style := StyleBoxFlat.new()
	suit_style.bg_color = BACK_COLOR
	suit_style.corner_radius_top_left = 10
	suit_style.corner_radius_top_right = 10
	suit_style.corner_radius_bottom_left = 10
	suit_style.corner_radius_bottom_right = 10
	suit.add_theme_stylebox_override("panel", suit_style)
	mask.add_child(suit)

	# GUEST ラベル
	var lbl := Label.new()
	lbl.text = "GUEST"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", GUEST_LABEL_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	suit.add_child(lbl)

	return mask

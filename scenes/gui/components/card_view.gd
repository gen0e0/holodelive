class_name CardView
extends Control

signal card_clicked(instance_id: int)

const CARD_WIDTH: int = 120
const CARD_HEIGHT: int = 168

var instance_id: int = -1
var _face_up: bool = true
var _card_data: Dictionary = {}
var _hovered: bool = false

var _bg_rect: ColorRect
var _name_label: Label
var _info_label: Label


## スートごとの背景色（キーは文字列: StateSerializer が String で格納するため）
static var SUIT_COLORS: Dictionary = {
	"LOVELY": Color(0.95, 0.5, 0.65),    # ピンク
	"COOL": Color(0.4, 0.55, 0.9),        # 青
	"HOT": Color(0.9, 0.35, 0.3),         # 赤
	"ENGLISH": Color(0.65, 0.45, 0.85),   # 紫
	"INDONESIA": Color(0.35, 0.75, 0.45), # 緑
	"STAFF": Color(0.9, 0.8, 0.3),        # 黄
}

const BACK_COLOR := Color(0.35, 0.35, 0.4)


func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)

	# 背景
	_bg_rect = ColorRect.new()
	_bg_rect.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_bg_rect.color = BACK_COLOR
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	# 名前ラベル
	_name_label = Label.new()
	_name_label.position = Vector2(4, 4)
	_name_label.size = Vector2(CARD_WIDTH - 8, 40)
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	# アイコン/スート情報ラベル
	_info_label = Label.new()
	_info_label.position = Vector2(4, CARD_HEIGHT - 50)
	_info_label.size = Vector2(CARD_WIDTH - 8, 46)
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_label)


func setup(card_data: Dictionary, face_up: bool) -> void:
	_card_data = card_data
	_face_up = face_up
	instance_id = card_data.get("instance_id", -1)
	_update_display()


func _update_display() -> void:
	if not _face_up or _card_data.get("hidden", false):
		_bg_rect.color = BACK_COLOR
		_name_label.text = "?"
		_info_label.text = ""
		return

	# スートで背景色決定（suits は Array[String]: "LOVELY", "COOL" 等）
	var suits: Array = _card_data.get("suits", [])
	if suits.size() > 0:
		var first_suit: String = suits[0]
		_bg_rect.color = SUIT_COLORS.get(first_suit, BACK_COLOR)
	else:
		_bg_rect.color = BACK_COLOR

	# 名前
	var nickname: String = _card_data.get("nickname", "?")
	var card_id: int = _card_data.get("card_id", 0)
	_name_label.text = "#%03d\n%s" % [card_id, nickname]

	# アイコン・スート略称（icons/suits は文字列配列）
	var icons: Array = _card_data.get("icons", [])
	var icon_strs: Array[String] = []
	for ic in icons:
		icon_strs.append(str(ic).left(3))
	var suit_strs: Array[String] = []
	for su in suits:
		suit_strs.append(str(su).left(3))
	_info_label.text = "%s\n%s" % [",".join(icon_strs), ",".join(suit_strs)]


func _draw() -> void:
	# カード枠線
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0, 0, 0, 0.6), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(instance_id)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			scale = Vector2(1.05, 1.05)
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			scale = Vector2(1.0, 1.0)

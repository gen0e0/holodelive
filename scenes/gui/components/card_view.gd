class_name CardView
extends Control

signal card_clicked(instance_id: int)

## true の場合、組み込みホバー演出を無効化（HandZone など親が管理）
var managed_hover: bool = false

var instance_id: int = -1
var _face_up: bool = true
var _card_data: Dictionary = {}
var _hovered: bool = false

@onready var _bg_panel: Panel = $BgPanel
@onready var _character_rect: TextureRect = $BgPanel/CharacterRect
@onready var _name_label: Label = $NameLabel
@onready var _info_label: Label = $InfoLabel
@onready var _icon_container: HBoxContainer = $IconContainer

const ICON_VIEW_SCENE: PackedScene = preload("res://scenes/gui/components/icon_view.tscn")


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


func setup(card_data: Dictionary, face_up: bool) -> void:
	_card_data = card_data
	_face_up = face_up
	instance_id = card_data.get("instance_id", -1)
	# @onready 完了前に呼ばれた場合は _ready() で描画
	if is_node_ready():
		_update_display()


func _ready() -> void:
	# StyleBoxFlat を複製して各インスタンス固有にする
	var style: StyleBoxFlat = _bg_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		_bg_panel.add_theme_stylebox_override("panel", style.duplicate())
	_update_display()


func _update_display() -> void:
	if _bg_panel == null:
		return

	if not _face_up or _card_data.get("hidden", false):
		_set_bg_color(BACK_COLOR)
		_character_rect.texture = null
		_name_label.text = "?"
		_info_label.text = ""
		_clear_icons()
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
	var style: StyleBoxFlat = _bg_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = color


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(instance_id)


func _notification(what: int) -> void:
	if managed_hover:
		return
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			scale = Vector2(1.05, 1.05)
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			scale = Vector2(1.0, 1.0)

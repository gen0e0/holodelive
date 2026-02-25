class_name IconView
extends PanelContainer

## アイコン名（SEISO, VOCAL 等）。設定すると対応画像を読み込む
@export var icon_name: String = "":
	set(value):
		icon_name = value
		_load_texture()

const ICON_DIR := "res://resources/icons/"

@onready var _texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_texture()


func _load_texture() -> void:
	if _texture_rect == null:
		return
	if icon_name == "":
		_texture_rect.texture = null
		return
	var path: String = ICON_DIR + icon_name + ".png"
	if ResourceLoader.exists(path):
		_texture_rect.texture = load(path)
	else:
		_texture_rect.texture = null

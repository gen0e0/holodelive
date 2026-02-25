class_name OverlayButton
extends Button

## 半透明オーバーレイ用のスタイル付きボタン。
## OverlayButton.new() でスタイル適用済みのインスタンスが得られる。

const NORMAL_BG := Color(0.2, 0.5, 0.8, 0.35)
const HOVER_BG := Color(0.3, 0.6, 0.9, 0.5)
const PRESSED_BG := Color(0.15, 0.4, 0.7, 0.5)
const BORDER_COLOR := Color(0.4, 0.7, 1.0, 0.8)
const BORDER_WIDTH: int = 3
const CORNER_RADIUS: int = 12
const FONT_SIZE: int = 28
const BUTTON_MODULATE := Color(1, 1, 1, 0.85)


func _init() -> void:
	modulate = BUTTON_MODULATE
	visible = false
	add_theme_stylebox_override("normal", _create_style(NORMAL_BG))
	add_theme_stylebox_override("hover", _create_style(HOVER_BG))
	add_theme_stylebox_override("pressed", _create_style(PRESSED_BG))
	add_theme_font_size_override("font_size", FONT_SIZE)


static func create(label: String, rect: Rect2) -> OverlayButton:
	var btn := OverlayButton.new()
	btn.text = label
	btn.position = rect.position
	btn.size = rect.size
	return btn


func _create_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = BORDER_COLOR
	style.border_width_top = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_width_left = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	return style

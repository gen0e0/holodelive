class_name WinStar
extends Label

## 勝利星コンポーネント。
## 将来的に画像に差し替える場合は、このクラスを TextureRect ベースに変更する。

const STAR_TEXT: String = "★"
const COLOR_INACTIVE: Color = Color(0.4, 0.4, 0.4)  # グレー
const COLOR_ACTIVE: Color = Color(1.0, 0.85, 0.0)    # 黄色

var _active: bool = false


func _init() -> void:
	text = STAR_TEXT
	add_theme_font_size_override("font_size", 28)
	add_theme_color_override("font_color", COLOR_INACTIVE)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pivot_offset = Vector2(16, 16)


func set_active(active: bool, animate: bool = false) -> void:
	if _active == active:
		return
	_active = active
	var color: Color = COLOR_ACTIVE if active else COLOR_INACTIVE
	if animate and active:
		_bounce(color)
	else:
		add_theme_color_override("font_color", color)


func _bounce(color: Color) -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	# 拡大
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_method(_set_color, COLOR_INACTIVE, color, 0.15)
	# 縮小（バウンス）
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)


func _set_color(c: Color) -> void:
	add_theme_color_override("font_color", c)

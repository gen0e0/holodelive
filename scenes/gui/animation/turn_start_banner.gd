class_name TurnStartBanner
extends Control

## ターン開始演出バナー。
## 右からスライドイン → 中央で停止 → 左へスライドアウト。

const DESIGN_W: float = 1920.0
const BAND_H: float = 120.0
const FONT_SIZE: int = 72

const FADE_DURATION: float = 0.15
const SLIDE_IN_DURATION: float = 0.3
const HOLD_DURATION: float = 0.4
const SLIDE_OUT_DURATION: float = 0.3

@onready var _band: ColorRect = $Band
@onready var _label: Label = $Band/TitleLabel


## テキストを設定する。play() の前に呼ぶ。
func set_text(text: String) -> void:
	$Band/TitleLabel.text = text


## 演出を再生し、完了まで await する。
func play() -> void:
	# 初期状態: Band 透明、Label を右端外に配置
	_band.modulate.a = 0.0
	_label.position.x = DESIGN_W

	# 1) Band フェードイン
	var tween: Tween = create_tween()
	tween.tween_property(_band, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	# 2) Label スライドイン（右端外 → 中央）
	var center_x: float = (DESIGN_W - _label.size.x) / 2.0
	tween = create_tween()
	tween.tween_property(_label, "position:x", center_x, SLIDE_IN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# 3) 中央で停止
	await get_tree().create_timer(HOLD_DURATION).timeout

	# 4) Label スライドアウト（中央 → 左端外）
	var out_x: float = -_label.size.x
	tween = create_tween()
	tween.tween_property(_label, "position:x", out_x, SLIDE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	# 5) Band フェードアウト
	tween = create_tween()
	tween.tween_property(_band, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished

	# 6) 自己破棄
	queue_free()

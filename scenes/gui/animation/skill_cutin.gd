class_name SkillCutIn
extends Control

## スキル詠唱カットイン演出。
## 自分のスキル → 左端から右へ / 相手のスキル → 右端から左へ Band がスライドする。

const DESIGN_W: float = 1920.0

const SLIDE_IN_DURATION: float = 0.25
const HOLD_DURATION: float = 0.35
const SLIDE_OUT_DURATION: float = 0.25
const FADE_DURATION: float = 0.1

var _from_left: bool = true  # true=自分(左から), false=相手(右から)

@onready var _band: ColorRect = $Band
@onready var _skill_label: Label = $Band/SkillLabel
@onready var _nickname_label: Label = $Band/NicknameLabel


## 表示内容と方向を設定する。play() の前に呼ぶ。
func setup(skill_name: String, nickname: String, from_left: bool) -> void:
	_from_left = from_left
	$Band/SkillLabel.text = skill_name
	$Band/NicknameLabel.text = nickname


## 演出を再生し、完了まで await する。
func play() -> void:
	_band.modulate.a = 0.0
	# 初期位置: 左端外 or 右端外
	_band.position.x = -_band.size.x if _from_left else DESIGN_W

	# 1) Band フェードイン
	var tween: Tween = create_tween()
	tween.tween_property(_band, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	# 2) スライドイン（端 → 中央）
	var center_x: float = (DESIGN_W - _band.size.x) / 2.0
	tween = create_tween()
	tween.tween_property(_band, "position:x", center_x, SLIDE_IN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# 3) 中央停止
	await get_tree().create_timer(HOLD_DURATION).timeout

	# 4) スライドアウト（中央 → 反対側の端外）
	var out_x: float = DESIGN_W if _from_left else -_band.size.x
	tween = create_tween()
	tween.tween_property(_band, "position:x", out_x, SLIDE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	# 5) Band フェードアウト
	tween = create_tween()
	tween.tween_property(_band, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished

	# 6) 自己破棄
	queue_free()

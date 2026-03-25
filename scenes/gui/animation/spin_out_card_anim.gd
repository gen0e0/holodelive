class_name SpinOutCardAnim
extends Control

## カード回転ジャンプ移動アニメーション。
## anim_layer に add_child すると即座にアニメーション開始。
## 完了時に finished シグナルを発火し、自動で queue_free する。

signal finished

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const PIVOT: Vector2 = Vector2(150, 210)
const SPIN_OUT_DURATION: float = 0.6
const JUMP_HEIGHT: float = 120.0

var _card_data: Dictionary
var _face_up: bool
var _from_xform: Dictionary
var _to_xform: Dictionary
var _base_delay: float


static func create(card_data: Dictionary, face_up: bool,
		from_xform: Dictionary, to_xform: Dictionary,
		delay: float = 0.0) -> SpinOutCardAnim:
	var anim := SpinOutCardAnim.new()
	anim._card_data = card_data
	anim._face_up = face_up
	anim._from_xform = from_xform
	anim._to_xform = to_xform
	anim._base_delay = delay
	return anim


func _ready() -> void:
	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(_card_data, _face_up)

	var from_pos: Vector2 = _from_xform.get("pos", Vector2.ZERO)
	cv.position = from_pos
	cv.scale = _from_xform.get("scale", Vector2.ONE)
	cv.rotation = _from_xform.get("rotation", 0.0)
	cv.pivot_offset = PIVOT
	add_child(cv)

	var to_pos: Vector2 = _to_xform.get("pos", Vector2.ZERO)
	var to_scale: Vector2 = _to_xform.get("scale", Vector2.ONE)
	var dur: float = _dur(SPIN_OUT_DURATION)
	var d: float = _dur(_base_delay)

	var tw: Tween = cv.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "position:x", to_pos.x, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(d)
	tw.tween_method(
		func(t: float) -> void:
			var linear_y: float = lerpf(from_pos.y, to_pos.y, t)
			var arc: float = 4.0 * JUMP_HEIGHT * t * (1.0 - t)
			cv.position.y = linear_y - arc,
		0.0, 1.0, dur
	).set_delay(d)
	tw.tween_property(cv, "rotation", TAU, dur) \
		.set_trans(Tween.TRANS_LINEAR).set_delay(d)
	tw.tween_property(cv, "scale", to_scale, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(d)
	tw.finished.connect(_on_finished)


func _on_finished() -> void:
	finished.emit()
	queue_free()


static func _dur(seconds: float) -> float:
	var s: float = GameConfig.animation_speed
	if s <= 0.0:
		return 0.0
	return seconds / s

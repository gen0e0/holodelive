class_name FlyCardAnim
extends Control

## カード直線移動アニメーション。
## anim_layer に add_child すると即座にアニメーション開始。
## 完了時に finished シグナルを発火し、自動で queue_free する。
##
## 使い方:
##   var anim = FlyCardAnim.create(card_data, face_up, from, to, duration, delay)
##   _anim_layer.add_child(anim)
##   await anim.finished  # 待ちたい場合のみ

signal finished

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")

var _card_data: Dictionary
var _face_up: bool
var _from_xform: Dictionary
var _to_xform: Dictionary
var _base_duration: float
var _base_delay: float


static func create(card_data: Dictionary, face_up: bool,
		from_xform: Dictionary, to_xform: Dictionary,
		duration: float = 0.35, delay: float = 0.0) -> FlyCardAnim:
	var anim := FlyCardAnim.new()
	anim._card_data = card_data
	anim._face_up = face_up
	anim._from_xform = from_xform
	anim._to_xform = to_xform
	anim._base_duration = duration
	anim._base_delay = delay
	return anim


func _ready() -> void:
	var cv: CardView = _CardViewScene.instantiate()
	cv.managed_hover = true
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.setup(_card_data, _face_up)
	cv.position = _from_xform.get("pos", Vector2.ZERO)
	cv.scale = _from_xform.get("scale", Vector2.ONE)
	cv.rotation = _from_xform.get("rotation", 0.0)
	add_child(cv)

	var dur: float = _dur(_base_duration)
	var d: float = _dur(_base_delay)

	var tw: Tween = cv.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "position", _to_xform.get("pos", Vector2.ZERO), dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(d)
	tw.tween_property(cv, "scale", _to_xform.get("scale", Vector2.ONE), dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(d)
	tw.tween_property(cv, "rotation", _to_xform.get("rotation", 0.0), dur) \
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

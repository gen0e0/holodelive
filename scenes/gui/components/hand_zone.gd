class_name HandZone
extends Control

## 手札ゾーン。CardView を扇形（円弧）に配置し、ホバー時に拡大・隣接カード退避を行う。

signal card_clicked(instance_id: int)

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")

@export var is_interactive: bool = true

@export_group("Arc Layout")
@export var arc_radius: float = 1800.0
@export var arc_angle: float = PI / 12.0
@export var card_offset_y: float = -60.0
@export var gap_pitch: float = 5.0

@export_group("Hover Effect")
@export var hover_scale: float = 1.2
@export var hover_offset_y: float = 200.0
@export var hover_shift_x: float = 120.0

@export_group("Animation")
@export var animation_duration: float = 0.2

var _hover_index: int = -1
var _card_views: Array = []  # Array[CardView]


func sync_cards(cards: Array, face_up: bool) -> void:
	var new_ids: Array = []
	for c in cards:
		new_ids.append(c.get("instance_id", -1))

	var current_ids: Array = []
	for cv in _card_views:
		current_ids.append(cv.instance_id)

	if current_ids == new_ids:
		# 同じカード構成 — データだけ更新
		for i in range(_card_views.size()):
			_card_views[i].setup(cards[i], face_up)
		return

	# カード構成が変わった — 再構築
	for cv in _card_views:
		cv.queue_free()
	_card_views.clear()
	_hover_index = -1

	for card_data in cards:
		var cv: CardView = _CardViewScene.instantiate()
		cv.managed_hover = true
		cv.setup(card_data, face_up)
		if is_interactive:
			cv.mouse_entered.connect(_on_card_hover.bind(cv))
			cv.mouse_exited.connect(_on_card_unhover)
		cv.card_clicked.connect(func(iid: int) -> void: card_clicked.emit(iid))
		add_child(cv)
		_card_views.append(cv)

	_reposition(false)


func sync_hidden(count: int) -> void:
	var cards: Array = []
	for i in range(count):
		cards.append({"instance_id": -1000 - i, "hidden": true})
	sync_cards(cards, false)


# ---------------------------------------------------------------------------
# ホバー
# ---------------------------------------------------------------------------

func _on_card_hover(cv: CardView) -> void:
	if not is_interactive:
		return
	var idx: int = _card_views.find(cv)
	if idx >= 0:
		_hover_index = idx
		_reposition(true)


func _on_card_unhover() -> void:
	if not is_interactive:
		return
	_hover_index = -1
	_reposition(true)


# ---------------------------------------------------------------------------
# 扇形配置
# ---------------------------------------------------------------------------

func _reposition(animate: bool) -> void:
	var count: int = _card_views.size()
	if count == 0:
		return

	# カード枚数に応じて扇の開き角度を調整
	var pitch: float = gap_pitch if count > 2 else 7.0
	var dynamic_arc: float = minf(arc_angle * (float(count) / pitch), arc_angle)

	for i in range(count):
		var t: float = float(i) / float(count - 1) if count > 1 else 0.5
		var angle: float = lerpf(-dynamic_arc, dynamic_arc, t)

		var card_x: float = sin(angle) * arc_radius
		var card_y: float = arc_radius + card_offset_y - cos(angle) * arc_radius
		var target_scale := Vector2.ONE
		var extra_x: float = 0.0
		var target_angle: float = angle

		if _hover_index >= 0 and i == _hover_index:
			card_y = -hover_offset_y
			target_scale = Vector2(hover_scale, hover_scale)
			target_angle = 0.0
		elif _hover_index >= 0 and i < _hover_index:
			extra_x = -hover_shift_x
		elif _hover_index >= 0 and i > _hover_index:
			extra_x = hover_shift_x

		var cv: CardView = _card_views[i]
		# pivot_offset 基準で中央配置
		var target_pos := Vector2(card_x + extra_x, card_y) - cv.pivot_offset

		# z-order: ホバー中のカードを最前面に
		cv.z_index = count + 1 if (_hover_index >= 0 and i == _hover_index) else i

		if animate:
			var tween: Tween = cv.create_tween()
			tween.set_parallel(true)
			tween.tween_property(cv, "position", target_pos, animation_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(cv, "rotation", target_angle, animation_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(cv, "scale", target_scale, animation_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			cv.position = target_pos
			cv.rotation = target_angle
			cv.scale = target_scale

class_name CardLayer
extends Control

## CardView の生成・破棄・配置を管理する。
## ClientState とFieldLayout を受け取り、全カードを正しい位置に同期する。

signal card_clicked(instance_id: int)

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")

var _card_views: Dictionary = {}  # instance_id -> CardView


func sync_state(cs: ClientState, field_layout: FieldLayout) -> void:
	var active_ids: Dictionary = {}  # instance_id -> true

	# --- ステージ ---
	for p in range(2):
		var stage_cards: Array = cs.stages[p]
		for i in range(stage_cards.size()):
			var card_data: Dictionary = stage_cards[i]
			var iid: int = card_data.get("instance_id", -1)
			var _hidden: bool = card_data.get("hidden", false)
			active_ids[iid] = true
			var pos: Vector2 = field_layout.get_stage_slot_pos(p, i)
			_ensure_card(iid, card_data, not _hidden, pos)

	# --- 楽屋 ---
	for p in range(2):
		var bs: Variant = cs.backstages[p]
		if bs != null:
			var card_data: Dictionary = bs
			var iid: int = card_data.get("instance_id", -1)
			var _hidden: bool = card_data.get("hidden", false)
			active_ids[iid] = true
			var pos: Vector2 = field_layout.get_backstage_slot_pos(p)
			_ensure_card(iid, card_data, not _hidden, pos)

	# --- 消えたカードを破棄 ---
	var to_remove: Array = []
	for iid in _card_views:
		if not active_ids.has(iid):
			to_remove.append(iid)
	for iid in to_remove:
		var cv: CardView = _card_views[iid]
		cv.queue_free()
		_card_views.erase(iid)


func _ensure_card(iid: int, card_data: Dictionary, face_up: bool, pos: Vector2, card_scale: float = 1.0) -> void:
	var cv: CardView
	if _card_views.has(iid):
		cv = _card_views[iid]
		cv.setup(card_data, face_up)
		cv.position = pos
		cv.scale = Vector2(card_scale, card_scale)
	else:
		cv = _CardViewScene.instantiate()
		cv.setup(card_data, face_up)
		cv.position = pos
		cv.scale = Vector2(card_scale, card_scale)
		cv.card_clicked.connect(_on_card_clicked)
		add_child(cv)
		_card_views[iid] = cv


func _on_card_clicked(iid: int) -> void:
	card_clicked.emit(iid)

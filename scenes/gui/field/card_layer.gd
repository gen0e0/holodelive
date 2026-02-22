class_name CardLayer
extends Control

## CardView の生成・破棄・配置を管理する。
## ClientState とFieldLayout を受け取り、全カードを正しい位置に同期する。

signal card_clicked(instance_id: int)

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")

var _card_views: Dictionary = {}  # instance_id -> CardView


func sync_state(cs: ClientState, field_layout: FieldLayout) -> void:
	var active_ids: Dictionary = {}  # instance_id -> true

	# --- 自分の手札 ---
	for i in range(cs.my_hand.size()):
		var card_data: Dictionary = cs.my_hand[i]
		var iid: int = card_data.get("instance_id", -1)
		active_ids[iid] = true
		var pos: Vector2 = field_layout.get_my_hand_slot_pos(i)
		_ensure_card(iid, card_data, true, pos)

	# --- 相手の手札（裏向き） ---
	for i in range(cs.opponent_hand_count):
		var fake_id: int = -1000 - i  # 負のIDで相手手札を識別
		active_ids[fake_id] = true
		var pos: Vector2 = field_layout.get_opp_hand_slot_pos(i)
		_ensure_card(fake_id, {"hidden": true}, false, pos)

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

	# --- デッキ（枚数表示用） ---
	if cs.deck_count > 0:
		var deck_id: int = -2000
		active_ids[deck_id] = true
		var pos: Vector2 = field_layout.get_deck_slot_pos()
		_ensure_card(deck_id, {"hidden": true, "nickname": "Deck\n%d" % cs.deck_count}, false, pos)

	# --- 自宅（最上部のみ表示） ---
	if cs.home.size() > 0:
		var home_id: int = -3000
		active_ids[home_id] = true
		var card_data: Dictionary = cs.home[cs.home.size() - 1]
		var pos: Vector2 = field_layout.get_home_slot_pos()
		_ensure_card(home_id, card_data, true, pos)

	# --- 消えたカードを破棄 ---
	var to_remove: Array = []
	for iid in _card_views:
		if not active_ids.has(iid):
			to_remove.append(iid)
	for iid in to_remove:
		var cv: CardView = _card_views[iid]
		cv.queue_free()
		_card_views.erase(iid)


func _ensure_card(iid: int, card_data: Dictionary, face_up: bool, pos: Vector2) -> void:
	var cv: CardView
	if _card_views.has(iid):
		cv = _card_views[iid]
		cv.setup(card_data, face_up)
		cv.position = pos
	else:
		cv = _CardViewScene.instantiate()
		cv.setup(card_data, face_up)
		cv.position = pos
		cv.card_clicked.connect(_on_card_clicked)
		add_child(cv)
		_card_views[iid] = cv


func _on_card_clicked(iid: int) -> void:
	card_clicked.emit(iid)

class_name FieldLayout
extends Control

## SlotMarker 配置を管理する。
## 1920x1080 の固定座標レイアウト。Y座標はエディタで調整可能。
## カードサイズは card_view.tscn のルートノードから取得する。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")

@export var gap: int = 12

@export_group("Layout Y Positions")
@export var y_opp_hand: int = 40
@export var y_opp_stage: int = 230
@export var y_shared: int = 430
@export var y_my_stage: int = 600
@export var y_my_hand: int = 800

@export_group("Field")
@export var field_w: int = 1920

# カードサイズ（card_view.tscn から取得）
var card_w: int
var card_h: int

# スロット格納
var _opp_hand_slots: Array = []   # Array[SlotMarker]
var _opp_stage_slots: Array = []  # Array[SlotMarker]
var _opp_backstage_slot: SlotMarker
var _my_stage_slots: Array = []   # Array[SlotMarker]
var _my_backstage_slot: SlotMarker
var _my_hand_slots: Array = []    # Array[SlotMarker]
var _deck_slot: SlotMarker
var _home_slot: SlotMarker


func _ready() -> void:
	var card_state: SceneState = _CardViewScene.get_state()
	var root_idx: int = 0
	for i in range(card_state.get_node_property_count(root_idx)):
		var prop_name: String = card_state.get_node_property_name(root_idx, i)
		if prop_name == "custom_minimum_size":
			var v: Vector2 = card_state.get_node_property_value(root_idx, i)
			card_w = int(v.x)
			card_h = int(v.y)
			break
	if card_w == 0:
		card_w = 120
		card_h = 168
	_build_fixed_slots()


func _build_fixed_slots() -> void:
	# --- 相手ステージ (3) + 楽屋 (1) ---
	var stage_total_w: int = card_w * 3 + gap * 2
	var stage_start_x: int = (field_w - stage_total_w) / 2 - (card_w + gap) / 2
	for i in range(3):
		var slot: SlotMarker = _create_slot(SlotMarker.SlotType.STAGE, 1, i)
		slot.position = Vector2(stage_start_x + i * (card_w + gap), y_opp_stage)
		_opp_stage_slots.append(slot)

	_opp_backstage_slot = _create_slot(SlotMarker.SlotType.BACKSTAGE, 1, 0)
	_opp_backstage_slot.position = Vector2(
		stage_start_x + 3 * (card_w + gap), y_opp_stage
	)

	# --- 自分ステージ (3) + 楽屋 (1) ---
	for i in range(3):
		var slot: SlotMarker = _create_slot(SlotMarker.SlotType.STAGE, 0, i)
		slot.position = Vector2(stage_start_x + i * (card_w + gap), y_my_stage)
		_my_stage_slots.append(slot)

	_my_backstage_slot = _create_slot(SlotMarker.SlotType.BACKSTAGE, 0, 0)
	_my_backstage_slot.position = Vector2(
		stage_start_x + 3 * (card_w + gap), y_my_stage
	)

	# --- 共有: デッキ + 自宅 ---
	var shared_start_x: int = (field_w - (card_w * 2 + gap)) / 2
	_deck_slot = _create_slot(SlotMarker.SlotType.DECK, -1, 0)
	_deck_slot.position = Vector2(shared_start_x, y_shared)

	_home_slot = _create_slot(SlotMarker.SlotType.HOME, -1, 0)
	_home_slot.position = Vector2(shared_start_x + card_w + gap, y_shared)


func update_layout(cs: ClientState) -> void:
	# 手札スロットは動的枚数なので毎回再生成
	_rebuild_hand_slots(_opp_hand_slots, cs.opponent_hand_count, 1, y_opp_hand)
	_rebuild_hand_slots(_my_hand_slots, cs.my_hand.size(), 0, y_my_hand)


func _rebuild_hand_slots(slots: Array, count: int, player: int, y: int) -> void:
	for s in slots:
		s.queue_free()
	slots.clear()

	if count == 0:
		return

	var total_w: int = card_w * count + gap * (count - 1)
	var start_x: int = (field_w - total_w) / 2
	for i in range(count):
		var slot: SlotMarker = _create_slot(SlotMarker.SlotType.HAND, player, i)
		slot.position = Vector2(start_x + i * (card_w + gap), y)
		slots.append(slot)


func _create_slot(type: SlotMarker.SlotType, player: int, index: int) -> SlotMarker:
	var slot := SlotMarker.new()
	slot.slot_type = type
	slot.player = player
	slot.slot_index = index
	slot.custom_minimum_size = Vector2(card_w, card_h)
	slot.size = Vector2(card_w, card_h)
	add_child(slot)
	return slot


# --- スロット位置取得 API ---

func get_my_hand_slot_pos(index: int) -> Vector2:
	if index >= 0 and index < _my_hand_slots.size():
		return _my_hand_slots[index].position
	return Vector2.ZERO


func get_opp_hand_slot_pos(index: int) -> Vector2:
	if index >= 0 and index < _opp_hand_slots.size():
		return _opp_hand_slots[index].position
	return Vector2.ZERO


func get_stage_slot_pos(player: int, index: int) -> Vector2:
	var slots: Array = _my_stage_slots if player == 0 else _opp_stage_slots
	if index >= 0 and index < slots.size():
		return slots[index].position
	return Vector2.ZERO


func get_backstage_slot_pos(player: int) -> Vector2:
	if player == 0:
		return _my_backstage_slot.position
	return _opp_backstage_slot.position


func get_deck_slot_pos() -> Vector2:
	return _deck_slot.position


func get_home_slot_pos() -> Vector2:
	return _home_slot.position

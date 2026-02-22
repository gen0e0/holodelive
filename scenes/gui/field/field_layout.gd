class_name FieldLayout
extends Control

## SlotMarker 配置を管理する。
## 1920x1080 の固定座標レイアウト。

const CARD_W: int = 120
const CARD_H: int = 168
const GAP: int = 12
const FIELD_W: int = 1920

# Y座標
const Y_OPP_HAND: int = 40
const Y_OPP_STAGE: int = 230
const Y_SHARED: int = 430
const Y_MY_STAGE: int = 600
const Y_MY_HAND: int = 800

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
	_build_fixed_slots()


func _build_fixed_slots() -> void:
	# --- 相手ステージ (3) + 楽屋 (1) ---
	var stage_total_w: int = CARD_W * 3 + GAP * 2
	var stage_start_x: int = (FIELD_W - stage_total_w) / 2 - (CARD_W + GAP) / 2
	for i in range(3):
		var slot: SlotMarker = _create_slot(SlotMarker.SlotType.STAGE, 1, i)
		slot.position = Vector2(stage_start_x + i * (CARD_W + GAP), Y_OPP_STAGE)
		_opp_stage_slots.append(slot)

	_opp_backstage_slot = _create_slot(SlotMarker.SlotType.BACKSTAGE, 1, 0)
	_opp_backstage_slot.position = Vector2(
		stage_start_x + 3 * (CARD_W + GAP), Y_OPP_STAGE
	)

	# --- 自分ステージ (3) + 楽屋 (1) ---
	for i in range(3):
		var slot: SlotMarker = _create_slot(SlotMarker.SlotType.STAGE, 0, i)
		slot.position = Vector2(stage_start_x + i * (CARD_W + GAP), Y_MY_STAGE)
		_my_stage_slots.append(slot)

	_my_backstage_slot = _create_slot(SlotMarker.SlotType.BACKSTAGE, 0, 0)
	_my_backstage_slot.position = Vector2(
		stage_start_x + 3 * (CARD_W + GAP), Y_MY_STAGE
	)

	# --- 共有: デッキ + 自宅 ---
	var shared_start_x: int = (FIELD_W - (CARD_W * 2 + GAP)) / 2
	_deck_slot = _create_slot(SlotMarker.SlotType.DECK, -1, 0)
	_deck_slot.position = Vector2(shared_start_x, Y_SHARED)

	_home_slot = _create_slot(SlotMarker.SlotType.HOME, -1, 0)
	_home_slot.position = Vector2(shared_start_x + CARD_W + GAP, Y_SHARED)


func update_layout(cs: ClientState) -> void:
	# 手札スロットは動的枚数なので毎回再生成
	_rebuild_hand_slots(_opp_hand_slots, cs.opponent_hand_count, 1, Y_OPP_HAND)
	_rebuild_hand_slots(_my_hand_slots, cs.my_hand.size(), 0, Y_MY_HAND)


func _rebuild_hand_slots(slots: Array, count: int, player: int, y: int) -> void:
	for s in slots:
		s.queue_free()
	slots.clear()

	if count == 0:
		return

	var total_w: int = CARD_W * count + GAP * (count - 1)
	var start_x: int = (FIELD_W - total_w) / 2
	for i in range(count):
		var slot: SlotMarker = _create_slot(SlotMarker.SlotType.HAND, player, i)
		slot.position = Vector2(start_x + i * (CARD_W + GAP), y)
		slots.append(slot)


func _create_slot(type: SlotMarker.SlotType, player: int, index: int) -> SlotMarker:
	var slot := SlotMarker.new()
	slot.slot_type = type
	slot.player = player
	slot.slot_index = index
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

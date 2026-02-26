class_name FieldLayout
extends Control

## SlotMarker 配置を管理する。
## 1920x1080 の固定座標レイアウト。スロット位置は tscn で定義。

@onready var _my_stage_slots: Array[SlotMarker] = [
	$MyStage1, $MyStage2, $MyStage3
]
@onready var _opp_stage_slots: Array[SlotMarker] = [
	$OppStage1, $OppStage2, $OppStage3
]
@onready var _my_backstage_slot: SlotMarker = $MyBackstage
@onready var _opp_backstage_slot: SlotMarker = $OppBackstage
@onready var _deck_slot: SlotMarker = $Deck
@onready var _home_slot: SlotMarker = $Home


func update_layout(_cs: ClientState) -> void:
	# 手札は HandZone が管理するため、ここでは何もしない
	pass


# --- スロット位置取得 API ---

func get_stage_slot_pos(player: int, index: int) -> Vector2:
	var slots: Array[SlotMarker] = _my_stage_slots if player == 0 else _opp_stage_slots
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

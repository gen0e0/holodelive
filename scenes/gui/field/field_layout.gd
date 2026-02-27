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

## トークン管理: "player:type" → TurnFlagToken
var _active_tokens: Dictionary = {}

## トークン配置の基準座標 (自分側左端 / 相手側右端)
const MY_TOKEN_BASE := Vector2(20, 80)
const OPP_TOKEN_BASE := Vector2(1820, 80)
const TOKEN_SPACING: float = 90.0


func update_layout(cs: ClientState) -> void:
	_sync_tokens(cs)


## field_effects からトークンを同期する。
func _sync_tokens(cs: ClientState) -> void:
	# 現在の field_effects からキーセットを構築
	var active_keys: Dictionary = {}
	for fe_dict in cs.field_effects:
		var fe_type: String = fe_dict.get("type", "") if fe_dict is Dictionary else ""
		var fe_target: int = fe_dict.get("target_player", -1) if fe_dict is Dictionary else -1
		var key: String = "%d:%s" % [fe_target, fe_type]
		active_keys[key] = fe_dict

	# 消えたトークンを削除
	var keys_to_remove: Array = []
	for key in _active_tokens:
		if not active_keys.has(key):
			var token: TurnFlagToken = _active_tokens[key]
			if is_instance_valid(token):
				token.queue_free()
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_active_tokens.erase(key)

	# 新しいトークンを追加
	for key in active_keys:
		if not _active_tokens.has(key):
			var fe_dict: Dictionary = active_keys[key]
			var token := TurnFlagToken.new()
			token.setup(fe_dict.get("type", ""))
			add_child(token)
			_active_tokens[key] = token

	# トークンを再配置
	_layout_tokens(cs.my_player)


## トークンを自分側/相手側に振り分けて縦に並べる。
func _layout_tokens(my_player: int) -> void:
	var my_idx: int = 0
	var opp_idx: int = 0
	for key in _active_tokens:
		var token: TurnFlagToken = _active_tokens[key]
		if not is_instance_valid(token):
			continue
		var parts: PackedStringArray = key.split(":")
		var target: int = int(parts[0])
		if target == my_player:
			token.position = MY_TOKEN_BASE + Vector2(0, my_idx * TOKEN_SPACING)
			my_idx += 1
		else:
			token.position = OPP_TOKEN_BASE + Vector2(0, opp_idx * TOKEN_SPACING)
			opp_idx += 1


## 消滅対象のトークンキーを取得する（prev_cs と new_cs の差分）。
func get_consumed_token_keys(prev_effects: Array, new_effects: Array) -> Array:
	var new_keys: Dictionary = {}
	for fe in new_effects:
		var key: String = "%d:%s" % [fe.get("target_player", -1), fe.get("type", "")]
		new_keys[key] = true

	var consumed: Array = []
	for fe in prev_effects:
		var key: String = "%d:%s" % [fe.get("target_player", -1), fe.get("type", "")]
		if not new_keys.has(key):
			consumed.append(key)
	return consumed


## 指定キーのトークンで consume アニメーションを再生する。
func play_consume_animation(key: String) -> void:
	if _active_tokens.has(key):
		var token: TurnFlagToken = _active_tokens[key]
		_active_tokens.erase(key)
		if is_instance_valid(token):
			await token.consume()


# --- スロット参照取得 API ---

func get_stage_slot(player: int, index: int) -> SlotMarker:
	var slots: Array[SlotMarker] = _my_stage_slots if player == 0 else _opp_stage_slots
	if index >= 0 and index < slots.size():
		return slots[index]
	return null


func get_backstage_slot(player: int) -> SlotMarker:
	if player == 0:
		return _my_backstage_slot
	return _opp_backstage_slot

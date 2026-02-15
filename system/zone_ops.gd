class_name ZoneOps
extends RefCounted

## デッキからカードを1枚ドローしてプレイヤーの手札に加える。
## 成功時は instance_id、デッキが空なら -1 を返す。
static func draw_card(state: GameState, player: int, recorder: DiffRecorder) -> int:
	if state.deck.is_empty():
		return -1
	var id: int = state.deck.pop_front()
	state.hands[player].append(id)
	recorder.record_card_move(id, "deck", 0, "hand", state.hands[player].size() - 1)
	return id


## 手札からカードをステージにプレイする（表向き）。
## slot が -1 の場合、最初の空きスロットを使う。
## 成功時は true。
static func play_to_stage(state: GameState, player: int, instance_id: int, slot: int, recorder: DiffRecorder) -> bool:
	if slot == -1:
		slot = state.first_empty_stage_slot(player)
	if slot == -1 or slot >= 3:
		return false
	if state.stages[player][slot] != -1:
		return false

	var hand_idx: int = state.hands[player].find(instance_id)
	if hand_idx == -1:
		return false

	state.hands[player].remove_at(hand_idx)
	state.stages[player][slot] = instance_id
	state.instances[instance_id].face_down = false
	recorder.record_card_move(instance_id, "hand", hand_idx, "stage", slot)
	recorder.record_card_flip(instance_id, false, false)
	return true


## 手札からカードを楽屋に配置する（裏向き）。
## 成功時は true。
static func play_to_backstage(state: GameState, player: int, instance_id: int, recorder: DiffRecorder) -> bool:
	if state.backstages[player] != -1:
		return false

	var hand_idx: int = state.hands[player].find(instance_id)
	if hand_idx == -1:
		return false

	state.hands[player].remove_at(hand_idx)
	state.backstages[player] = instance_id
	state.instances[instance_id].face_down = true
	recorder.record_card_move(instance_id, "hand", hand_idx, "backstage", 0)
	recorder.record_card_flip(instance_id, false, true)
	return true


## 楽屋のカードを表向きにする（オープン）。
## 成功時は true。
static func open_backstage(state: GameState, player: int, recorder: DiffRecorder) -> bool:
	var id: int = state.backstages[player]
	if id == -1:
		return false
	var inst: CardInstance = state.instances[id]
	if not inst.face_down:
		return false
	recorder.record_card_flip(id, true, false)
	inst.face_down = false
	return true


## カードを自宅に移動する。
static func move_to_home(state: GameState, instance_id: int, recorder: DiffRecorder) -> void:
	var zone := state.find_zone(instance_id)
	_remove_from_zone(state, instance_id, zone)
	state.home.append(instance_id)
	recorder.record_card_move(instance_id, zone.get("zone", ""), zone.get("index", -1), "home", state.home.size() - 1)


## カードをゲームから除外する。
static func remove_card(state: GameState, instance_id: int, recorder: DiffRecorder) -> void:
	var zone := state.find_zone(instance_id)
	_remove_from_zone(state, instance_id, zone)
	state.removed.append(instance_id)
	recorder.record_card_move(instance_id, zone.get("zone", ""), zone.get("index", -1), "removed", state.removed.size() - 1)


## ゾーンからカードを取り除く（内部ヘルパー）。
static func _remove_from_zone(state: GameState, instance_id: int, zone: Dictionary) -> void:
	if zone.is_empty():
		return
	var zone_name: String = zone["zone"]
	match zone_name:
		"deck":
			state.deck.erase(instance_id)
		"hand":
			state.hands[zone["player"]].erase(instance_id)
		"stage":
			state.stages[zone["player"]][zone["index"]] = -1
		"backstage":
			state.backstages[zone["player"]] = -1
		"home":
			state.home.erase(instance_id)
		"removed":
			state.removed.erase(instance_id)

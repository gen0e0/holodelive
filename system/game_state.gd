class_name GameState
extends RefCounted

# --- インスタンス管理 ---
var next_instance_id: int = 0
var instances: Dictionary = {}  # int → CardInstance

# --- ゾーン（全て instance_id を格納）---
var deck: Array[int] = []
var hands: Array = [[], []]  # [Array[int], Array[int]]
var stages: Array = [[-1, -1, -1], [-1, -1, -1]]  # 各プレイヤー3スロット、空=-1
var backstages: Array = [-1, -1]  # 各プレイヤー1枠、空=-1
var home: Array[int] = []
var removed: Array[int] = []

# --- ゲーム進行 ---
var current_player: int = 0
var phase: Enums.Phase = Enums.Phase.ACTION
var round_number: int = 1
var turn_number: int = 1
var round_wins: Array[int] = [0, 0]
var live_ready: Array = [false, false]
var live_ready_turn: Array[int] = [-1, -1]

# --- スキル解決スタック ---
var skill_stack: Array = []  # Array[SkillStackEntry]

# --- スキル解決中の選択待ち ---
var pending_choices: Array = []  # Array[PendingChoice]

# --- 履歴 ---
var action_log: Array = []  # Array[GameAction]


## CardInstance を生成し instances に登録。instance_id を返す。
func create_instance(card_id: int) -> int:
	var id := next_instance_id
	next_instance_id += 1
	var inst := CardInstance.new(id, card_id)
	instances[id] = inst
	return id


## 指定 instance_id がどのゾーンにあるかを返す。
## 戻り値: {"zone": String, "player": int(-1 if shared), "index": int}
## 見つからない場合は空 Dictionary。
func find_zone(instance_id: int) -> Dictionary:
	# deck
	var idx := deck.find(instance_id)
	if idx != -1:
		return {"zone": "deck", "player": -1, "index": idx}

	# hands
	for p in range(2):
		idx = hands[p].find(instance_id)
		if idx != -1:
			return {"zone": "hand", "player": p, "index": idx}

	# stages
	for p in range(2):
		for s in range(3):
			if stages[p][s] == instance_id:
				return {"zone": "stage", "player": p, "index": s}

	# backstages
	for p in range(2):
		if backstages[p] == instance_id:
			return {"zone": "backstage", "player": p, "index": 0}

	# home
	idx = home.find(instance_id)
	if idx != -1:
		return {"zone": "home", "player": -1, "index": idx}

	# removed
	idx = removed.find(instance_id)
	if idx != -1:
		return {"zone": "removed", "player": -1, "index": idx}

	return {}


## プレイヤーのステージに配置されているカード数を返す。
func stage_count(player: int) -> int:
	var count := 0
	for s in range(3):
		if stages[player][s] != -1:
			count += 1
	return count


## プレイヤーのステージで最初の空きスロットを返す。なければ -1。
func first_empty_stage_slot(player: int) -> int:
	for s in range(3):
		if stages[player][s] == -1:
			return s
	return -1

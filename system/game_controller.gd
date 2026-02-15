class_name GameController
extends RefCounted

var state: GameState
var registry: CardRegistry
var _recorder: DiffRecorder


func _init(p_state: GameState, p_registry: CardRegistry) -> void:
	state = p_state
	registry = p_registry
	_recorder = DiffRecorder.new()


## ターン開始: ライブチェック → ドロー → ACTION フェーズ。
## ライブが発生した場合は true を返す。
func start_turn() -> bool:
	_log_action(Enums.ActionType.TURN_START, state.current_player, {})

	# ライブチェック（ドロー前）
	if state.live_ready[state.current_player]:
		_trigger_live()
		return true

	# ドロー
	_do_draw(state.current_player)

	# ACTION フェーズへ
	_set_phase(Enums.Phase.ACTION)
	return false


## 現在のフェーズと盤面から有効なアクションを算出して返す。
## 各アクション: {"type": ActionType, ...追加パラメータ}
func get_available_actions() -> Array:
	var actions: Array = []
	var p := state.current_player

	match state.phase:
		Enums.Phase.ACTION:
			# 楽屋オープン
			if state.backstages[p] != -1:
				var inst: CardInstance = state.instances[state.backstages[p]]
				if inst.face_down:
					actions.append({"type": Enums.ActionType.OPEN, "instance_id": state.backstages[p]})
			# パス（ACTION フェーズを終了）
			actions.append({"type": Enums.ActionType.PASS})

		Enums.Phase.PLAY:
			var hand: Array = state.hands[p]
			if hand.is_empty():
				# 手札がない場合はスキップ扱い
				actions.append({"type": Enums.ActionType.PASS})
			else:
				# ステージの空きスロットにプレイ
				for slot in range(3):
					if state.stages[p][slot] == -1:
						for card_id in hand:
							actions.append({"type": Enums.ActionType.PLAY_CARD, "instance_id": card_id, "target": "stage", "slot": slot})
				# 楽屋にプレイ
				if state.backstages[p] == -1:
					for card_id in hand:
						actions.append({"type": Enums.ActionType.PLAY_CARD, "instance_id": card_id, "target": "backstage"})

	return actions


## アクションを適用する。
func apply_action(action: Dictionary) -> void:
	_recorder.clear()
	var p := state.current_player
	var action_type: Enums.ActionType = action["type"]

	match action_type:
		Enums.ActionType.PASS:
			if state.phase == Enums.Phase.ACTION:
				_set_phase(Enums.Phase.PLAY)
			elif state.phase == Enums.Phase.PLAY:
				end_turn()
			_log_action(Enums.ActionType.PASS, p, {})

		Enums.ActionType.OPEN:
			ZoneOps.open_backstage(state, p, _recorder)
			_log_action(Enums.ActionType.OPEN, p, {"instance_id": action["instance_id"]})
			# オープン後もまだ ACTION フェーズ

		Enums.ActionType.PLAY_CARD:
			var inst_id: int = action["instance_id"]
			var target: String = action["target"]
			if target == "stage":
				var slot: int = action.get("slot", -1)
				ZoneOps.play_to_stage(state, p, inst_id, slot, _recorder)
			elif target == "backstage":
				ZoneOps.play_to_backstage(state, p, inst_id, _recorder)
			_log_action(Enums.ActionType.PLAY_CARD, p, action)
			end_turn()


## ターン終了処理。
func end_turn() -> void:
	var p := state.current_player

	# Home 溢れチェック: 5枚超 → 古い順に除外
	while state.home.size() > 5:
		var oldest: int = state.home[0]
		ZoneOps.remove_card(state, oldest, _recorder)

	# ライブレディチェック: ステージ3枚埋まっている → ライブ準備
	if state.stage_count(p) == 3 and not state.live_ready[p]:
		state.live_ready[p] = true
		state.live_ready_turn[p] = state.turn_number

	_log_action(Enums.ActionType.TURN_END, p, {})

	# プレイヤー交代
	state.current_player = 1 - p
	state.turn_number += 1

	# アクションスキル使用済みフラグをリセット
	for inst_id in state.instances:
		state.instances[inst_id].action_skill_used = false


## ライブ発動。
## 相手が未準備なら自動勝利、両者準備ならショウダウン。
func _trigger_live() -> void:
	_set_phase(Enums.Phase.LIVE)
	var p := state.current_player
	var opponent := 1 - p

	if not state.live_ready[opponent]:
		# 相手未準備 → 自動勝利
		_record_round_win(p)
		_do_round_cleanup()
	else:
		# 両者準備 → ショウダウン
		_set_phase(Enums.Phase.SHOWDOWN)
		var winner := _resolve_showdown()
		_record_round_win(winner)
		_do_round_cleanup()


## ショウダウン解決。MVP: アイコン数の合計で比較。
## 同点なら live_ready_turn が早い方が勝ち。
func _resolve_showdown() -> int:
	var scores: Array[int] = [0, 0]
	for p in range(2):
		scores[p] = _count_unit_icons(p)

	if scores[0] > scores[1]:
		return 0
	elif scores[1] > scores[0]:
		return 1
	else:
		# 同点 → ライブ準備が早い方
		if state.live_ready_turn[0] <= state.live_ready_turn[1]:
			return 0
		else:
			return 1


## プレイヤーのユニット（ステージ + 表向き楽屋）のアイコン数合計。
func _count_unit_icons(player: int) -> int:
	var count := 0
	# ステージ
	for s in range(3):
		var id: int = state.stages[player][s]
		if id != -1:
			var inst: CardInstance = state.instances[id]
			var card_def := registry.get_card(inst.card_id)
			if card_def:
				count += card_def.base_icons.size()
	# 楽屋（表向きのみ参加）
	var bs_id: int = state.backstages[player]
	if bs_id != -1:
		var bs_inst: CardInstance = state.instances[bs_id]
		if not bs_inst.face_down:
			var card_def := registry.get_card(bs_inst.card_id)
			if card_def:
				count += card_def.base_icons.size()
	return count


## ラウンド勝利を記録。
func _record_round_win(player: int) -> void:
	state.round_wins[player] += 1
	_log_action(Enums.ActionType.ROUND_END, player, {"winner": player})


## ラウンドクリーンアップ。
## ステージのカードを除外、楽屋のカードをステージへ移動、ライブレディリセット。
func _do_round_cleanup() -> void:
	_recorder.clear()
	for p in range(2):
		# ステージのカードを除外
		for s in range(3):
			var id: int = state.stages[p][s]
			if id != -1:
				state.stages[p][s] = -1
				state.removed.append(id)

		# 楽屋のカードをステージに移動（裏向きのまま維持）
		var bs_id: int = state.backstages[p]
		if bs_id != -1:
			state.backstages[p] = -1
			state.stages[p][0] = bs_id

	# ライブレディリセット
	state.live_ready[0] = false
	state.live_ready[1] = false
	state.live_ready_turn[0] = -1
	state.live_ready_turn[1] = -1

	# ラウンド番号更新
	state.round_number += 1

	# フェーズリセット
	_set_phase(Enums.Phase.ACTION)


## ゲーム終了判定。
func is_game_over() -> bool:
	return state.round_wins[0] >= 3 or state.round_wins[1] >= 3


## 勝者を返す。ゲーム未終了なら -1。
func get_winner() -> int:
	if state.round_wins[0] >= 3:
		return 0
	if state.round_wins[1] >= 3:
		return 1
	return -1


func _do_draw(player: int) -> void:
	_recorder.clear()
	var drawn := ZoneOps.draw_card(state, player, _recorder)
	if drawn != -1:
		_log_action(Enums.ActionType.DRAW, player, {"instance_id": drawn})


func _set_phase(new_phase: Enums.Phase) -> void:
	_recorder.clear()
	_recorder.record_property_change("phase", state.phase, new_phase)
	state.phase = new_phase


func _log_action(type: Enums.ActionType, player: int, params: Dictionary) -> void:
	var ga := GameAction.new(type, player, params)
	ga.diffs = _recorder.diffs.duplicate()
	state.action_log.append(ga)

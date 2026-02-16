class_name GameController
extends RefCounted

var state: GameState
var registry: CardRegistry
var skill_registry: SkillRegistry
var _recorder: DiffRecorder
var _pending_end_turn: bool = false


func _init(p_state: GameState, p_registry: CardRegistry, p_skill_registry: SkillRegistry = null) -> void:
	state = p_state
	registry = p_registry
	skill_registry = p_skill_registry if p_skill_registry else SkillRegistry.new()
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

			# 表向きフィールドカードの未使用アクションスキル
			var face_up_ids := _get_face_up_field_ids(p)
			for inst_id in face_up_ids:
				var inst: CardInstance = state.instances[inst_id]
				var card_def: CardDef = registry.get_card(inst.card_id)
				if card_def and not card_def.skills.is_empty():
					for i in range(card_def.skills.size()):
						var skill_meta: Dictionary = card_def.skills[i]
						if skill_meta.get("type") == Enums.SkillType.ACTION and not inst.action_skills_used.has(i):
							actions.append({
								"type": Enums.ActionType.ACTIVATE_SKILL,
								"instance_id": inst_id,
								"skill_index": i,
							})

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
			var inst_id: int = action["instance_id"]
			ZoneOps.open_backstage(state, p, _recorder)
			_log_action(Enums.ActionType.OPEN, p, {"instance_id": inst_id})
			# オープン後、play skill を試行（ACTION フェーズ続行）
			_try_trigger_play_skill(inst_id, p)

		Enums.ActionType.PLAY_CARD:
			var inst_id: int = action["instance_id"]
			var target: String = action["target"]
			if target == "stage":
				var slot: int = action.get("slot", -1)
				ZoneOps.play_to_stage(state, p, inst_id, slot, _recorder)
				_log_action(Enums.ActionType.PLAY_CARD, p, action)
				_pending_end_turn = true
				_try_trigger_play_skill(inst_id, p)
				if _pending_end_turn and state.skill_stack.is_empty() and not is_waiting_for_choice():
					_pending_end_turn = false
					end_turn()
			elif target == "backstage":
				ZoneOps.play_to_backstage(state, p, inst_id, _recorder)
				_log_action(Enums.ActionType.PLAY_CARD, p, action)
				end_turn()

		Enums.ActionType.ACTIVATE_SKILL:
			var inst_id: int = action["instance_id"]
			var skill_index: int = action["skill_index"]
			var inst: CardInstance = state.instances[inst_id]
			inst.action_skills_used.append(skill_index)
			_log_action(Enums.ActionType.ACTIVATE_SKILL, p, action)
			_push_skill(inst.card_id, skill_index, inst_id, p)
			_fire_trigger(Enums.TriggerEvent.SKILL_ACTIVATED, {
				"card_id": inst.card_id,
				"skill_index": skill_index,
				"instance_id": inst_id,
				"player": p,
			})
			_resolve_skill_stack()


## スキル解決中の選択待ちがあるか。
func is_waiting_for_choice() -> bool:
	for pc in state.pending_choices:
		if not pc.resolved:
			return true
	return false


## プレイヤー選択を提出する。
func submit_choice(choice_index: int, chosen_value: Variant) -> void:
	if choice_index < 0 or choice_index >= state.pending_choices.size():
		return
	var pc: PendingChoice = state.pending_choices[choice_index]
	pc.resolved = true
	pc.result = chosen_value

	# カウンター選択判定: valid_targets に -1 を含む場合
	var is_counter_choice := pc.valid_targets.has(-1)
	if is_counter_choice:
		if chosen_value == -1:
			# パス: カウンターしない
			state.pending_choices.clear()
			_resolve_skill_stack()
		else:
			# カウンタースキルを発動
			var counter_inst_id: int = chosen_value
			var counter_inst: CardInstance = state.instances[counter_inst_id]
			var counter_card_def: CardDef = registry.get_card(counter_inst.card_id)
			# パッシブスキル（最初のpassive）のインデックスを探す
			var counter_skill_index := _find_passive_skill_index(counter_card_def)
			if counter_skill_index != -1:
				# 元スキルを COUNTERED にする
				if not state.skill_stack.is_empty():
					var top: SkillStackEntry = state.skill_stack.back()
					top.state = Enums.SkillState.COUNTERED
				state.pending_choices.clear()
				_push_skill(counter_inst.card_id, counter_skill_index, counter_inst_id, pc.target_player)
				_fire_trigger(Enums.TriggerEvent.SKILL_ACTIVATED, {
					"card_id": counter_inst.card_id,
					"skill_index": counter_skill_index,
					"instance_id": counter_inst_id,
					"player": pc.target_player,
				})
				_resolve_skill_stack()
	else:
		# 通常選択: 全 PendingChoice 解決済みなら再開
		var all_resolved := true
		for pending in state.pending_choices:
			if not pending.resolved:
				all_resolved = false
				break
		if all_resolved:
			_resolve_skill_stack()


## ターン終了処理。
func end_turn() -> void:
	var p := state.current_player

	# Home 溢れチェック: 5枚超 → 古い順に除外
	while state.home.size() > 5:
		var oldest: int = state.home[0]
		ZoneOps.remove_card(state, oldest, _recorder)
		_fire_trigger(Enums.TriggerEvent.CARD_LEFT_ZONE, {"instance_id": oldest})

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
		state.instances[inst_id].action_skills_used.clear()


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


## ショウダウン解決。ランク比較で勝者を決定。
## 同ランクなら live_ready_turn が早い方が勝ち。
func _resolve_showdown() -> int:
	var ranks: Array[int] = [0, 0]
	for p in range(2):
		var unit := _get_unit_data(p)
		ranks[p] = ShowdownCalculator.evaluate_rank(unit)

	# ランクは値が小さいほど強い
	if ranks[0] < ranks[1]:
		return 0
	elif ranks[1] < ranks[0]:
		return 1
	else:
		# 同ランク → ライブ準備が早い方
		if state.live_ready_turn[0] <= state.live_ready_turn[1]:
			return 0
		else:
			return 1


## プレイヤーのユニット（ステージ + 表向き楽屋）の実効値リストを返す。
## 戻り値: Array of {"icons": Array[String], "suits": Array[String]}
func _get_unit_data(player: int) -> Array:
	var unit: Array = []
	# ステージ
	for s in range(3):
		var id: int = state.stages[player][s]
		if id != -1:
			var inst: CardInstance = state.instances[id]
			var card_def := registry.get_card(inst.card_id)
			if card_def:
				unit.append({"icons": inst.effective_icons(card_def), "suits": inst.effective_suits(card_def)})
	# 楽屋（表向きのみ参加）
	var bs_id: int = state.backstages[player]
	if bs_id != -1:
		var bs_inst: CardInstance = state.instances[bs_id]
		if not bs_inst.face_down:
			var card_def := registry.get_card(bs_inst.card_id)
			if card_def:
				unit.append({"icons": bs_inst.effective_icons(card_def), "suits": bs_inst.effective_suits(card_def)})
	return unit


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
				_fire_trigger(Enums.TriggerEvent.CARD_LEFT_ZONE, {"instance_id": id})

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


# --- スキル解決エンジン ---


## スキルをスタックに積む。
func _push_skill(card_id: int, skill_index: int, instance_id: int, player: int) -> void:
	var entry := SkillStackEntry.new()
	entry.card_id = card_id
	entry.skill_index = skill_index
	entry.source_instance_id = instance_id
	entry.player = player
	entry.state = Enums.SkillState.PENDING
	state.skill_stack.append(entry)


## play skill のトリガーを試みる。
func _try_trigger_play_skill(instance_id: int, player: int) -> void:
	var inst: CardInstance = state.instances[instance_id]
	var card_def: CardDef = registry.get_card(inst.card_id)
	if not card_def or card_def.skills.is_empty():
		return

	# 最初の play skill を探す
	for i in range(card_def.skills.size()):
		var skill_meta: Dictionary = card_def.skills[i]
		if skill_meta.get("type") == Enums.SkillType.PLAY:
			if skill_registry.has_skill(inst.card_id):
				_push_skill(inst.card_id, i, instance_id, player)
				_fire_trigger(Enums.TriggerEvent.SKILL_ACTIVATED, {
					"card_id": inst.card_id,
					"skill_index": i,
					"instance_id": instance_id,
					"player": player,
				})
				_resolve_skill_stack()
				return


## スキルスタックを LIFO で解決する。
func _resolve_skill_stack() -> void:
	while not state.skill_stack.is_empty():
		# カウンター選択待ちなら中断
		if is_waiting_for_choice():
			return

		var top: SkillStackEntry = state.skill_stack.back()

		if top.state == Enums.SkillState.COUNTERED:
			state.skill_stack.pop_back()
			continue

		if top.state == Enums.SkillState.RESOLVED:
			state.skill_stack.pop_back()
			continue

		# PENDING → RESOLVING
		top.state = Enums.SkillState.RESOLVING

		var skill_script: BaseCardSkill = skill_registry.get_skill(top.card_id)
		if not skill_script:
			top.state = Enums.SkillState.RESOLVED
			state.skill_stack.pop_back()
			continue

		# SkillContext を構築
		var ctx := SkillContext.new(
			state,
			registry,
			top.source_instance_id,
			top.player,
			top.phase,
			null,
			_recorder
		)
		# 前回の選択結果があればセット
		if not state.pending_choices.is_empty():
			for pc in state.pending_choices:
				if pc.resolved and pc.stack_index == state.skill_stack.size() - 1:
					ctx.choice_result = pc.result
					break
		ctx.data = top.data

		var result: SkillResult = skill_script.execute_skill(ctx, top.skill_index)
		top.data = ctx.data

		if result.status == SkillResult.Status.WAITING_FOR_CHOICE:
			# 中断: PendingChoice を作成
			var pc := PendingChoice.new()
			pc.stack_index = state.skill_stack.size() - 1
			pc.skill_source_instance_id = top.source_instance_id
			pc.target_player = top.player
			pc.choice_type = result.choice_type
			pc.valid_targets = result.valid_targets
			state.pending_choices.clear()
			state.pending_choices.append(pc)
			top.phase += 1
			return  # 中断

		# DONE
		top.state = Enums.SkillState.RESOLVED
		state.skill_stack.pop_back()

	# スタック空 → 完了
	_on_skill_stack_resolved()


## スキルスタック解決完了後の後処理。
func _on_skill_stack_resolved() -> void:
	state.pending_choices.clear()
	if _pending_end_turn:
		_pending_end_turn = false
		end_turn()


## トリガーイベントを発火する。
func _fire_trigger(event: Enums.TriggerEvent, details: Dictionary) -> void:
	match event:
		Enums.TriggerEvent.SKILL_ACTIVATED:
			_check_counter(details)
		Enums.TriggerEvent.CARD_LEFT_ZONE:
			_cleanup_modifiers(details["instance_id"])
		_:
			pass  # 将来拡張


## 非永続 Modifier のクリーンアップ。
## source_instance_id が一致し persistent == false の Modifier を全 CardInstance から除去する。
func _cleanup_modifiers(source_id: int) -> void:
	for inst_id in state.instances:
		var inst: CardInstance = state.instances[inst_id]
		var i := inst.modifiers.size() - 1
		while i >= 0:
			var mod: Modifier = inst.modifiers[i]
			if mod.source_instance_id == source_id and not mod.persistent:
				inst.modifiers.remove_at(i)
				_recorder.record_modifier_remove(inst_id, mod)
			i -= 1


## カウンター候補をチェックし、選択肢を提示する。
func _check_counter(details: Dictionary) -> void:
	var skill_player: int = details.get("player", 0)
	var opponent := 1 - skill_player
	var candidates: Array = []

	var face_up_ids := _get_face_up_field_ids(opponent)
	for inst_id in face_up_ids:
		var inst: CardInstance = state.instances[inst_id]
		var card_def: CardDef = registry.get_card(inst.card_id)
		if not card_def or card_def.skills.is_empty():
			continue
		# passive スキルで _can_counter == true のものを探す
		for i in range(card_def.skills.size()):
			var skill_meta: Dictionary = card_def.skills[i]
			if skill_meta.get("type") == Enums.SkillType.PASSIVE:
				var skill_script: BaseCardSkill = skill_registry.get_skill(inst.card_id)
				if skill_script:
					var ctx := SkillContext.new(state, registry, inst_id, opponent)
					if skill_script._can_counter(ctx):
						candidates.append(inst_id)
						break  # 1カードにつき1候補

	if candidates.is_empty():
		return

	# PendingChoice を作成: candidates + -1(パス)
	var targets := candidates.duplicate()
	targets.append(-1)
	var pc := PendingChoice.new()
	pc.stack_index = state.skill_stack.size() - 1
	pc.skill_source_instance_id = details.get("instance_id", -1)
	pc.target_player = opponent
	pc.choice_type = Enums.ChoiceType.SELECT_CARD
	pc.valid_targets = targets
	state.pending_choices.clear()
	state.pending_choices.append(pc)


## プレイヤーの表向きフィールドカード（ステージ + 表向き楽屋）の instance_id リスト。
func _get_face_up_field_ids(player: int) -> Array:
	var ids: Array = []
	for s in range(3):
		var id: int = state.stages[player][s]
		if id != -1:
			var inst: CardInstance = state.instances[id]
			if not inst.face_down:
				ids.append(id)
	var bs_id: int = state.backstages[player]
	if bs_id != -1:
		var bs_inst: CardInstance = state.instances[bs_id]
		if not bs_inst.face_down:
			ids.append(bs_id)
	return ids


## パッシブスキルのインデックスを探す。
func _find_passive_skill_index(card_def: CardDef) -> int:
	if not card_def:
		return -1
	for i in range(card_def.skills.size()):
		if card_def.skills[i].get("type") == Enums.SkillType.PASSIVE:
			return i
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

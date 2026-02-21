extends BaseCardSkill


## ネクロノミコン(passive): このカードの前後に接しているカードに、一時的にEN★を加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var adjacent: Array = _get_adjacent_ids(ctx)
	for id in adjacent:
		var mod: Modifier = Modifier.new(Enums.ModifierType.SUIT_ADD, "ENGLISH", ctx.source_instance_id, false)
		ctx.state.instances[id].modifiers.append(mod)
		ctx.recorder.record_modifier_add(id, mod)
	return SkillResult.done()


## ネクロノミコン(play): サイコロを振り、出た目の効果を使用する。
func _skill_1(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [1, 2, 3, 4, 5, 6])
	elif ctx.phase == 1:
		var roll: int = ctx.choice_result
		ctx.data["roll"] = roll
		match roll:
			1:
				# 帰宅
				ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
				return SkillResult.done()
			2:
				# 手札に戻す
				ZoneOps.move_to_hand(ctx.state, ctx.source_instance_id, ctx.player, ctx.recorder)
				return SkillResult.done()
			3:
				# 自宅から1枚手札に
				if ctx.state.home.is_empty():
					return SkillResult.done()
				ZoneOps.move_to_hand(ctx.state, ctx.state.home[0], ctx.player, ctx.recorder)
				return SkillResult.done()
			4:
				# 相手1stを手札に戻す
				if ctx.state.stages[opp].is_empty():
					return SkillResult.done()
				var opp_first: int = ctx.state.stages[opp][0]
				ZoneOps.move_to_hand(ctx.state, opp_first, opp, ctx.recorder)
				return SkillResult.done()
			5:
				# デッキ最下部のカードをプレイ
				if ctx.state.deck.is_empty():
					return SkillResult.done()
				var bottom: int = ctx.state.deck.back()
				if ctx.state.stages[ctx.player].size() < 3:
					ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, bottom, ctx.recorder)
				return SkillResult.done()
			6:
				# 相手場1枚選んで帰宅
				var targets: Array = _get_opp_field_ids(ctx)
				if targets.is_empty():
					return SkillResult.done()
				return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
		return SkillResult.done()
	else:
		# roll=6 の選択結果
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_home(ctx.state, chosen, ctx.recorder)
		return SkillResult.done()


func _get_adjacent_ids(ctx: SkillContext) -> Array:
	var stage: Array = ctx.state.stages[ctx.player]
	var idx: int = stage.find(ctx.source_instance_id)
	if idx == -1:
		return []
	var ids: Array = []
	if idx > 0:
		ids.append(stage[idx - 1])
	if idx < stage.size() - 1:
		ids.append(stage[idx + 1])
	return ids


func _get_opp_field_ids(ctx: SkillContext) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	for id in ctx.state.stages[opp]:
		ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1:
		ids.append(bs_id)
	return ids

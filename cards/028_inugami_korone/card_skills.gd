extends BaseCardSkill


## おらよ: 相手の場のカードを2枚選んで、手札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	elif ctx.phase == 1:
		# 1枚目を相手の手札に戻す
		var first: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, first, opp, ctx.recorder)
		# 2枚目の対象を確認
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		# 2枚目を相手の手札に戻す
		var second: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, second, opp, ctx.recorder)
		return SkillResult.done()


func _get_opp_field_ids(ctx: SkillContext) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	for id in ctx.state.stages[opp]:
		if not ctx.state.instances[id].face_down:
			ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1 and not ctx.state.instances[bs_id].face_down:
		ids.append(bs_id)
	return ids

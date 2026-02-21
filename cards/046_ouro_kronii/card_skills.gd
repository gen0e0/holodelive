extends BaseCardSkill


## タイムリープ: このカードを帰宅させる。相手の場にあるカードを２枚選んで手札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		# 自身を帰宅
		ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	elif ctx.phase == 1:
		# 1枚目を相手手札に
		var first: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, first, opp, ctx.recorder)
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		# 2枚目を相手手札に
		var second: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, second, opp, ctx.recorder)
		return SkillResult.done()


func _get_opp_field_ids(ctx: SkillContext) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	for id in ctx.state.stages[opp]:
		ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1:
		ids.append(bs_id)
	return ids

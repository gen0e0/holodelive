extends BaseCardSkill


## もう帰ろうぜ: このカードを帰宅させる。相手の場にあるカードを1枚帰宅させる（ゲスト可）。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		# 自身を帰宅
		ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
		# 相手場から選択
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_home(ctx.state, chosen, ctx.recorder)
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

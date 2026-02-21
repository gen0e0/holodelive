extends BaseCardSkill


## ぎゅむっ: 相手の場のカードを1枚、山札の一番上に置く。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_deck_top(ctx.state, chosen, ctx.recorder)
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

extends BaseCardSkill


## 見て見て！ギラファ！: 自分の場にあるこのカード以外のカードを1枚、手札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_my_field_ids_except_self(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, chosen, ctx.player, ctx.recorder)
		return SkillResult.done()


func _get_my_field_ids_except_self(ctx: SkillContext) -> Array:
	var ids: Array = []
	for id in ctx.state.stages[ctx.player]:
		if id != ctx.source_instance_id and not ctx.state.instances[id].face_down:
			ids.append(id)
	var bs_id: int = ctx.state.backstages[ctx.player]
	if bs_id != -1 and bs_id != ctx.source_instance_id and not ctx.state.instances[bs_id].face_down:
		ids.append(bs_id)
	return ids

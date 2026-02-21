extends BaseCardSkill


## 大丈夫ですか？？: 自宅にあるカードを1枚選んで、ステージにプレイする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.stages[ctx.player].size() >= 3:
			return SkillResult.done()
		if ctx.state.home.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate())
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, chosen, ctx.recorder)
		return SkillResult.done()

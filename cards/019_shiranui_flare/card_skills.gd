extends BaseCardSkill


## 俺のイナ！: 自宅から1枚選んで手札に加える。その後、相手は自宅から1枚選んで手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		if ctx.state.home.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate())
	elif ctx.phase == 1:
		# 自分が選んだカードを手札に加える
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, chosen, ctx.player, ctx.recorder)
		# 相手も自宅から選ぶ（自宅にカードが残っているか確認）
		if ctx.state.home.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate())
	else:
		# 相手が選んだカードを手札に加える
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, chosen, opp, ctx.recorder)
		return SkillResult.done()

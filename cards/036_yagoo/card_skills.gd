extends BaseCardSkill


## お茶会: 相手の手札からランダムに2枚引き、手札に加える。（1枚は残す）
## RANDOM_RESULT で対象カードを1枚ずつ決定する（最大2回）。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var opp_hand: Array = ctx.state.hands[opp]

	if ctx.phase == 0:
		if opp_hand.size() <= 1:
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, opp_hand.duplicate())
	elif ctx.phase == 1:
		var first_id: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, first_id, ctx.player, ctx.recorder)
		if opp_hand.size() <= 1:
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, opp_hand.duplicate())
	else:
		var second_id: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, second_id, ctx.player, ctx.recorder)
		return SkillResult.done()

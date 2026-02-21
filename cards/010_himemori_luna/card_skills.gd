extends BaseCardSkill


## くせえのら: 相手の手札をランダムに1枚、帰宅させる。
## RANDOM_RESULT で対象カードを決定する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var opp_hand: Array = ctx.state.hands[opp]
	if opp_hand.is_empty():
		return SkillResult.done()
	if ctx.phase == 0:
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, opp_hand.duplicate())
	else:
		var target_id: int = ctx.choice_result
		ZoneOps.move_to_home(ctx.state, target_id, ctx.recorder)
		return SkillResult.done()

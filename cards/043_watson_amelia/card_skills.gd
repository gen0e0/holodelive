extends BaseCardSkill


## グレムリンノイズ: あなたと相手の手札を、交換する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var my_hand: Array = ctx.state.hands[ctx.player].duplicate()
	var opp_hand: Array = ctx.state.hands[opp].duplicate()
	ctx.state.hands[ctx.player].clear()
	ctx.state.hands[opp].clear()
	for i in range(opp_hand.size()):
		ctx.state.hands[ctx.player].append(opp_hand[i])
		ctx.recorder.record_card_move(opp_hand[i], "hand", i, "hand", ctx.state.hands[ctx.player].size() - 1)
	for i in range(my_hand.size()):
		ctx.state.hands[opp].append(my_hand[i])
		ctx.recorder.record_card_move(my_hand[i], "hand", i, "hand", ctx.state.hands[opp].size() - 1)
	return SkillResult.done()

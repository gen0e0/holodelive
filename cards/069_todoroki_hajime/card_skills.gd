extends BaseCardSkill


## タイマンだじぇ: あなたのステージの1stカードと、相手ステージの1stカードを共に帰宅させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	# 相手の1stを帰宅
	if not ctx.state.stages[opp].is_empty():
		var opp_first: int = ctx.state.stages[opp][0]
		ZoneOps.move_to_home(ctx.state, opp_first, ctx.recorder)
	# 自分の1stを帰宅（自分自身を含んでもよい）
	if not ctx.state.stages[ctx.player].is_empty():
		var my_first: int = ctx.state.stages[ctx.player][0]
		ZoneOps.move_to_home(ctx.state, my_first, ctx.recorder)
	return SkillResult.done()

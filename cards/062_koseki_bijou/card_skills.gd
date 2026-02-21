extends BaseCardSkill


## 産んじゃう…！: このカードが１stまたは楽屋に出た時、対面ステージの1stカードを、こちらのステージに移動する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.state.stages[opp].is_empty():
		return SkillResult.done()
	if ctx.state.stages[ctx.player].size() >= 3:
		return SkillResult.done()
	var opp_first: int = ctx.state.stages[opp][0]
	ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, opp_first, ctx.recorder)
	return SkillResult.done()

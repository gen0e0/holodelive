extends BaseCardSkill


## じゃじゃーん！青くんでした！: このカードは直ちに相手のステージに移動する。
## その後、あなたは山札から１枚引いて手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.state.stages[opp].size() >= 3:
		return SkillResult.done()
	ZoneOps.play_to_stage_from_zone(ctx.state, opp, ctx.source_instance_id, ctx.recorder)
	ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
	return SkillResult.done()

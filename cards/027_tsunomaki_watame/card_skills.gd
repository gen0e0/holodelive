extends BaseCardSkill


## わるくないよねぇ: 相手は次のターン、ステージにプレイする事ができない。
## 角巻わためが場を離れた時、この効果は消失する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	ctx.state.turn_flags["no_stage_play"] = opp
	ctx.state.turn_flags["no_stage_play_source"] = ctx.source_instance_id
	return SkillResult.done()

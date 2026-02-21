extends BaseCardSkill


## こーせーのー: 山札の上から1枚引いて手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
	return SkillResult.done()

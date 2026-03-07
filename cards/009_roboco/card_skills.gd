extends BaseCardSkill


## こーせーのー: 山札の上から1枚引いて手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var drawn_iid: int = ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
	if drawn_iid >= 0:
		ctx.emit_cue(AnimationCue.make_card(drawn_iid).move().from_deck().to_my_hand())
	return SkillResult.done()

extends BaseCardSkill


## Big God Mio-n: 相手は手札を全て帰宅させ、2枚ドローする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var opp_hand: Array = ctx.state.hands[opp].duplicate()
	for id in opp_hand:
		ctx.emit_cue(AnimationCue.move(id))
		ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
	for i in range(2):
		var drawn_iid: int = ZoneOps.draw_card(ctx.state, opp, ctx.recorder)
		if drawn_iid >= 0:
			ctx.emit_cue(AnimationCue.move(drawn_iid))
	return SkillResult.done()

extends BaseCardSkill


## ゾンビパーティ: 山札の一番下のカードを手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.state.deck.is_empty():
		return SkillResult.done()
	var id: int = ctx.state.deck.back()
	ctx.emit_cue(AnimationCue.make_card(id).move().from_deck().to_my_hand())
	ZoneOps.move_to_hand(ctx.state, id, ctx.player, ctx.recorder)
	return SkillResult.done()

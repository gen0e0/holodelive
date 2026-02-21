extends BaseCardSkill


## ゾンビパーティ: 山札の一番下のカードを手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.state.deck.is_empty():
		return SkillResult.done()
	var id: int = ctx.state.deck.back()
	ZoneOps.move_to_hand(ctx.state, id, ctx.player, ctx.recorder)
	return SkillResult.done()

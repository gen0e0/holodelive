extends BaseCardSkill


## Mumei Berries: 手札を１枚選び、山札の一番下に置く。山札から１枚引いて手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var hand: Array = ctx.state.hands[ctx.player]
		if hand.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_deck_bottom(ctx.state, chosen, ctx.recorder)
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		return SkillResult.done()

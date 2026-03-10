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
		ctx.emit_cue(AnimationCue.find_card(chosen).move().from_my_hand().to_deck())
		ZoneOps.move_to_deck_bottom(ctx.state, chosen, ctx.recorder)
		var drawn: int = ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		if drawn != -1:
			ctx.emit_cue(AnimationCue.make_card(drawn).move().from_deck().to_my_hand())
		return SkillResult.done()

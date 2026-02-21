extends BaseCardSkill


## 入口の女: 山札から2枚引いて手札に加え、その後、手札から2枚選び好きな順番で山札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		# 2枚ドロー
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		var hand: Array = ctx.state.hands[ctx.player]
		if hand.size() < 2:
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	elif ctx.phase == 1:
		# 1枚目をデッキ上に戻す（これが2番目に積まれる）
		var first: int = ctx.choice_result
		ctx.data["first_returned"] = first
		ZoneOps.move_to_deck_top(ctx.state, first, ctx.recorder)
		var hand: Array = ctx.state.hands[ctx.player]
		if hand.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	else:
		# 2枚目をデッキ上に戻す（これが一番上になる）
		var second: int = ctx.choice_result
		ZoneOps.move_to_deck_top(ctx.state, second, ctx.recorder)
		return SkillResult.done()

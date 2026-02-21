extends BaseCardSkill


## 豪運うさぎってわーけ！: 手札から1枚選び、山札の一番上のカードと交換する。
## 交換してきたカードを場にプレイする。楽屋に伏せてゲストとしてもよい。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var hand: Array = ctx.state.hands[ctx.player]
		if hand.is_empty() or ctx.state.deck.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	elif ctx.phase == 1:
		# 手札のカードをデッキ上に、デッキ上のカードを手札に
		var chosen: int = ctx.choice_result
		var deck_top: int = ctx.state.deck[0]
		ZoneOps.move_to_deck_top(ctx.state, chosen, ctx.recorder)
		ZoneOps.move_to_hand(ctx.state, deck_top, ctx.player, ctx.recorder)
		ctx.data["drawn_card"] = deck_top
		# プレイ先を選択（stage or backstage）
		var targets: Array = []
		if ctx.state.stages[ctx.player].size() < 3:
			targets.append("stage")
		if ctx.state.backstages[ctx.player] == -1:
			targets.append("backstage")
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_ZONE, targets)
	else:
		var drawn_card: int = ctx.data.get("drawn_card", -1)
		var target: String = ctx.choice_result
		if target == "stage":
			ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, drawn_card, ctx.recorder)
		elif target == "backstage":
			ZoneOps.play_to_backstage_from_zone(ctx.state, ctx.player, drawn_card, ctx.recorder)
		return SkillResult.done()

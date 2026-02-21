extends BaseCardSkill


## ALiCE&u: 山札の上から2枚を見て、好きな1枚を手札に加える。選ばなかったカードを相手の手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		if ctx.state.deck.size() < 2:
			# デッキが1枚以下なら全部自分の手札に
			if not ctx.state.deck.is_empty():
				ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
			return SkillResult.done()
		# デッキ上2枚を確認
		var top1: int = ctx.state.deck[0]
		var top2: int = ctx.state.deck[1]
		ctx.data["card1"] = top1
		ctx.data["card2"] = top2
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, [top1, top2])
	else:
		var chosen: int = ctx.choice_result
		var card1: int = ctx.data.get("card1", -1)
		var card2: int = ctx.data.get("card2", -1)
		var other: int = card2 if chosen == card1 else card1
		# 選んだカードを自分の手札に
		ZoneOps.move_to_hand(ctx.state, chosen, ctx.player, ctx.recorder)
		# 選ばなかったカードを相手の手札に
		ZoneOps.move_to_hand(ctx.state, other, opp, ctx.recorder)
		return SkillResult.done()

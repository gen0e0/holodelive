extends BaseCardSkill


## マリ箱: 相手の場のカードを1枚選び、手札に戻す。その後、手札から楽屋にプレイする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	elif ctx.phase == 1:
		# 相手の場カードを相手の手札に戻す
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, chosen, opp, ctx.recorder)
		# 自分の手札から楽屋にプレイ
		if ctx.state.backstages[ctx.player] != -1:
			return SkillResult.done()
		var hand: Array = ctx.state.hands[ctx.player]
		if hand.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	else:
		var card_to_play: int = ctx.choice_result
		ZoneOps.play_to_backstage_from_zone(ctx.state, ctx.player, card_to_play, ctx.recorder)
		return SkillResult.done()


func _get_opp_field_ids(ctx: SkillContext) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	for id in ctx.state.stages[opp]:
		if not ctx.state.instances[id].face_down:
			ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1 and not ctx.state.instances[bs_id].face_down:
		ids.append(bs_id)
	return ids

extends BaseCardSkill


## a: 手札からEN★のカードを１枚、プレイする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.stages[ctx.player].size() >= 3:
			return SkillResult.done()
		var targets: Array = _get_hand_by_suits(ctx, ["ENGLISH"])
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, chosen, ctx.recorder)
		return SkillResult.done()


func _get_hand_by_suits(ctx: SkillContext, suit_filter: Array) -> Array:
	var ids: Array = []
	for id in ctx.state.hands[ctx.player]:
		var inst: CardInstance = ctx.state.instances[id]
		var card_def: CardDef = ctx.registry.get_card(inst.card_id)
		if not card_def:
			continue
		var suits: Array[String] = inst.effective_suits(card_def)
		for suit in suit_filter:
			if suits.has(suit):
				ids.append(id)
				break
	return ids

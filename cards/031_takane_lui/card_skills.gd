extends BaseCardSkill


## 有能女幹部: 自宅にあるEN★(ENGLISH)かID☽(INDONESIA)のカードを1枚、手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_home_by_suits(ctx, ["ENGLISH", "INDONESIA"])
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, chosen, ctx.player, ctx.recorder)
		return SkillResult.done()


func _get_home_by_suits(ctx: SkillContext, suit_filter: Array) -> Array:
	var ids: Array = []
	for id in ctx.state.home:
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

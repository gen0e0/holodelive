extends BaseCardSkill


## クソガキング KUSOGAKing: あなたの場にあるKUSOGAKIの枚数分、相手の場のカードを手札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		var kusogaki_count: int = _count_kusogaki(ctx)
		if kusogaki_count == 0:
			return SkillResult.done()
		ctx.data["remaining"] = kusogaki_count
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, chosen, opp, ctx.recorder)
		var remaining: int = ctx.data.get("remaining", 0) - 1
		ctx.data["remaining"] = remaining
		if remaining <= 0:
			return SkillResult.done()
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)


func _count_kusogaki(ctx: SkillContext) -> int:
	var count: int = 0
	for id in ctx.state.stages[ctx.player]:
		if _has_kusogaki(ctx, id):
			count += 1
	var bs_id: int = ctx.state.backstages[ctx.player]
	if bs_id != -1 and _has_kusogaki(ctx, bs_id):
		count += 1
	return count


func _has_kusogaki(ctx: SkillContext, instance_id: int) -> bool:
	var inst: CardInstance = ctx.state.instances[instance_id]
	var card_def: CardDef = ctx.registry.get_card(inst.card_id)
	if not card_def:
		return false
	var icons: Array[String] = inst.effective_icons(card_def)
	return icons.has("KUSOGAKI")


func _get_opp_field_ids(ctx: SkillContext) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	for id in ctx.state.stages[opp]:
		ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1:
		ids.append(bs_id)
	return ids

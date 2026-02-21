extends BaseCardSkill


## メンテナンス: 相手の場にあるDUELISTを1枚選び、帰宅させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_by_icon(ctx, "DUELIST")
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_home(ctx.state, chosen, ctx.recorder)
		return SkillResult.done()


func _get_opp_field_by_icon(ctx: SkillContext, icon: String) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	var candidates: Array = ctx.state.stages[opp].duplicate()
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1 and not ctx.state.instances[bs_id].face_down:
		candidates.append(bs_id)
	for id in candidates:
		var inst: CardInstance = ctx.state.instances[id]
		if inst.face_down:
			continue
		var card_def: CardDef = ctx.registry.get_card(inst.card_id)
		if not card_def:
			continue
		if inst.effective_icons(card_def).has(icon):
			ids.append(id)
	return ids

extends BaseCardSkill


## 癒しの極地: 相手の場にあるKUSOGAKIのカードを1枚選び、こちらのステージに移動させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.stages[ctx.player].size() >= 3:
			return SkillResult.done()
		var targets: Array = _get_opp_field_by_icon(ctx, "KUSOGAKI")
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, chosen, ctx.recorder)
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

extends BaseCardSkill


## Diva: ライブ準備時、好きなアイコンとして扱うことができる（WILD）。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var mod: Modifier = Modifier.new(Enums.ModifierType.ICON_ADD, "WILD", ctx.source_instance_id, false)
	ctx.state.instances[ctx.source_instance_id].modifiers.append(mod)
	ctx.recorder.record_modifier_add(ctx.source_instance_id, mod)
	return SkillResult.done()


## Guess!: 手札からSEISOのカードを１枚、プレイすることができる。
func _skill_1(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_hand_by_icons(ctx, ["SEISO"])
		if targets.is_empty():
			return SkillResult.done()
		var zones: Array = []
		if ctx.state.stages[ctx.player].size() < 3:
			zones.append("stage")
		if ctx.state.backstages[ctx.player] == -1:
			zones.append("backstage")
		if zones.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	elif ctx.phase == 1:
		var chosen: int = ctx.choice_result
		ctx.data["chosen_card"] = chosen
		var zones: Array = []
		if ctx.state.stages[ctx.player].size() < 3:
			zones.append("stage")
		if ctx.state.backstages[ctx.player] == -1:
			zones.append("backstage")
		if zones.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_ZONE, zones)
	else:
		var chosen: int = ctx.data.get("chosen_card", -1)
		var target: String = ctx.choice_result
		if target == "stage":
			ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, chosen, ctx.recorder)
		elif target == "backstage":
			ZoneOps.play_to_backstage_from_zone(ctx.state, ctx.player, chosen, ctx.recorder)
		return SkillResult.done()


func _get_hand_by_icons(ctx: SkillContext, icon_filter: Array) -> Array:
	var ids: Array = []
	for id in ctx.state.hands[ctx.player]:
		var inst: CardInstance = ctx.state.instances[id]
		var card_def: CardDef = ctx.registry.get_card(inst.card_id)
		if not card_def:
			continue
		var icons: Array[String] = inst.effective_icons(card_def)
		for icon in icon_filter:
			if icons.has(icon):
				ids.append(id)
				break
	return ids

extends BaseCardSkill


## 知識の収集家: 場、自宅のINTELの中から1枚選んで、手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_intel_from_field_and_home(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, chosen, ctx.player, ctx.recorder)
		return SkillResult.done()


func _get_intel_from_field_and_home(ctx: SkillContext) -> Array:
	var ids: Array = []
	# 両プレイヤーの場（ステージ + 表向き楽屋）から INTEL を探す（自身除外）
	for p in range(2):
		for id in ctx.state.stages[p]:
			if id == ctx.source_instance_id:
				continue
			var inst: CardInstance = ctx.state.instances[id]
			if inst.face_down:
				continue
			var card_def: CardDef = ctx.registry.get_card(inst.card_id)
			if card_def and inst.effective_icons(card_def).has("INTEL"):
				ids.append(id)
		var bs_id: int = ctx.state.backstages[p]
		if bs_id != -1 and bs_id != ctx.source_instance_id:
			var inst: CardInstance = ctx.state.instances[bs_id]
			if not inst.face_down:
				var card_def: CardDef = ctx.registry.get_card(inst.card_id)
				if card_def and inst.effective_icons(card_def).has("INTEL"):
					ids.append(bs_id)
	# 自宅から INTEL を探す
	for id in ctx.state.home:
		var inst: CardInstance = ctx.state.instances[id]
		var card_def: CardDef = ctx.registry.get_card(inst.card_id)
		if card_def and inst.effective_icons(card_def).has("INTEL"):
			ids.append(id)
	return ids

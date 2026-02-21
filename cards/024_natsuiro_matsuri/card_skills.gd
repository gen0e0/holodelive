extends BaseCardSkill


## まつりライン: 場にあるこのカード以外のSEISOアイコンを持つカードを全て帰宅させる。
## １枚でも帰宅させた場合、WILD能力を得る。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var to_remove: Array = []
	# 両プレイヤーのステージと楽屋
	for p in range(2):
		for id in ctx.state.stages[p]:
			if id == ctx.source_instance_id:
				continue
			if _has_seiso(ctx, id):
				to_remove.append(id)
		var bs_id: int = ctx.state.backstages[p]
		if bs_id != -1 and bs_id != ctx.source_instance_id:
			if _has_seiso(ctx, bs_id):
				to_remove.append(bs_id)
	for id in to_remove:
		ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
	# 1枚でも帰宅→WILD付与
	if not to_remove.is_empty():
		var mod: Modifier = Modifier.new(Enums.ModifierType.ICON_ADD, "WILD", ctx.source_instance_id, true)
		ctx.state.instances[ctx.source_instance_id].modifiers.append(mod)
		ctx.recorder.record_modifier_add(ctx.source_instance_id, mod)
	return SkillResult.done()


func _has_seiso(ctx: SkillContext, instance_id: int) -> bool:
	var inst: CardInstance = ctx.state.instances[instance_id]
	var card_def: CardDef = ctx.registry.get_card(inst.card_id)
	if not card_def:
		return false
	var icons: Array[String] = inst.effective_icons(card_def)
	return icons.has("SEISO")

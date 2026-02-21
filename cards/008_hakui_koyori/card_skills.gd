extends BaseCardSkill


## それこよの！: 相手の場にあるカードを１枚選び、そのプレイ時能力を使用する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	elif ctx.phase == 1:
		var chosen: int = ctx.choice_result
		ctx.data["target_card"] = chosen
		# 対象カードの play skill を実行
		var inst: CardInstance = ctx.state.instances[chosen]
		if ctx.skill_registry:
			var skill: BaseCardSkill = ctx.skill_registry.get_skill(inst.card_id)
			if skill:
				var sub_ctx := SkillContext.new(ctx.state, ctx.registry, chosen, ctx.player, 0, null, ctx.recorder, ctx.skill_registry)
				var sub_result: SkillResult = skill.execute_skill(sub_ctx, 0)
				if sub_result.status == SkillResult.Status.WAITING_FOR_CHOICE:
					ctx.data["sub_skill_card_id"] = inst.card_id
					ctx.data["sub_phase"] = 1
					return sub_result
		return SkillResult.done()
	else:
		# サブスキルの続行
		var card_id: int = ctx.data.get("sub_skill_card_id", -1)
		var sub_phase: int = ctx.data.get("sub_phase", 0)
		var target_card: int = ctx.data.get("target_card", -1)
		if ctx.skill_registry and card_id != -1:
			var skill: BaseCardSkill = ctx.skill_registry.get_skill(card_id)
			if skill:
				var sub_ctx := SkillContext.new(ctx.state, ctx.registry, target_card, ctx.player, sub_phase, ctx.choice_result, ctx.recorder, ctx.skill_registry)
				sub_ctx.data = ctx.data
				var sub_result: SkillResult = skill.execute_skill(sub_ctx, 0)
				if sub_result.status == SkillResult.Status.WAITING_FOR_CHOICE:
					ctx.data["sub_phase"] = sub_phase + 1
					return sub_result
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

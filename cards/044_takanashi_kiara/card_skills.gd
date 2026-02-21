extends BaseCardSkill


## HOLOTALK: 自宅にあるカードを１枚選び、そのプレイ時能力を使用する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.home.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate())
	elif ctx.phase == 1:
		var chosen: int = ctx.choice_result
		ctx.data["target_card"] = chosen
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

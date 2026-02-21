extends BaseCardSkill


## はあちゃまっちゃま～: 自宅にあるカードを１枚選んでこのカードと入れ替え、
## そのプレイ能力を発動させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.home.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate())
	elif ctx.phase == 1:
		var chosen: int = ctx.choice_result
		ctx.data["chosen_card"] = chosen
		# 自身の位置を特定
		var my_zone: Dictionary = ctx.state.find_zone(ctx.source_instance_id)
		# 選んだカードを自宅から除去して自身の位置に配置
		ctx.state.home.erase(chosen)
		# 自身を自宅へ
		var zone_name: String = my_zone.get("zone", "")
		if zone_name == "stage":
			var idx: int = ctx.state.stages[ctx.player].find(ctx.source_instance_id)
			ctx.state.stages[ctx.player].erase(ctx.source_instance_id)
			ctx.state.stages[ctx.player].insert(mini(idx, ctx.state.stages[ctx.player].size()), chosen)
			ctx.state.instances[chosen].face_down = false
		elif zone_name == "backstage":
			ctx.state.backstages[ctx.player] = chosen
			ctx.state.instances[chosen].face_down = ctx.state.instances[ctx.source_instance_id].face_down
		ctx.state.home.append(ctx.source_instance_id)
		ctx.recorder.record_card_move(ctx.source_instance_id, zone_name, 0, "home", ctx.state.home.size() - 1)
		ctx.recorder.record_card_move(chosen, "home", 0, zone_name, 0)
		# 配置したカードの play skill を発動
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
		# サブスキルの継続フェーズ
		var card_id: int = ctx.data.get("sub_skill_card_id", -1)
		var sub_phase: int = ctx.data.get("sub_phase", 0)
		var chosen: int = ctx.data.get("chosen_card", -1)
		if ctx.skill_registry and card_id != -1:
			var skill: BaseCardSkill = ctx.skill_registry.get_skill(card_id)
			if skill:
				var sub_ctx := SkillContext.new(ctx.state, ctx.registry, chosen, ctx.player, sub_phase, ctx.choice_result, ctx.recorder, ctx.skill_registry)
				sub_ctx.data = ctx.data
				var sub_result: SkillResult = skill.execute_skill(sub_ctx, 0)
				if sub_result.status == SkillResult.Status.WAITING_FOR_CHOICE:
					ctx.data["sub_phase"] = sub_phase + 1
					return sub_result
		return SkillResult.done()

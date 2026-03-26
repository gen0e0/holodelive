extends BaseCardSkill


## クソガキング KUSOGAKing: あなたの場にあるKUSOGAKIの枚数分、相手の場の表向きカードを選んで帰宅させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var kusogaki_count: int = _count_kusogaki(ctx)
		if kusogaki_count == 0:
			return SkillResult.done()
		var targets: Array = _get_opp_face_up_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		var count: int = mini(kusogaki_count, targets.size())
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets,
			count, count)
	else:
		# 選択結果は配列（複数選択）
		var chosen: Variant = ctx.choice_result
		if chosen is Array:
			var delay: float = 0.0
			for id in chosen:
				ctx.emit_cue(AnimationCue.find_card(id).move().to_home().with_delay(delay))
				ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
				delay += 0.1
		else:
			ctx.emit_cue(AnimationCue.find_card(chosen).move().to_home())
			ZoneOps.move_to_home(ctx.state, chosen, ctx.recorder)
		return SkillResult.done()


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


func _get_opp_face_up_field_ids(ctx: SkillContext) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	for id in ctx.state.stages[opp]:
		var inst: CardInstance = ctx.state.instances[id]
		if not inst.face_down:
			ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1:
		var inst: CardInstance = ctx.state.instances[bs_id]
		if not inst.face_down:
			ids.append(bs_id)
	return ids

extends BaseCardSkill


## おらよ: 相手の場のカードを最大2枚選んで、手札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		# 1〜2枚を一括選択（対象が1枚なら1枚でOK）
		var max_pick: int = mini(2, targets.size())
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets, 1, max_pick)
	else:
		# 選択結果は Array（複数枚） or 単一値（1枚）
		var chosen: Array
		if ctx.choice_result is Array:
			chosen = ctx.choice_result
		else:
			chosen = [ctx.choice_result]
		var delay: float = 0.0
		for iid in chosen:
			ctx.emit_cue(AnimationCue.find_card(iid).move().to_op_hand().with_delay(delay))
			ZoneOps.move_to_hand(ctx.state, iid, opp, ctx.recorder)
			delay += 0.15
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

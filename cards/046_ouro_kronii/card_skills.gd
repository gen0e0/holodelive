extends BaseCardSkill


## タイムリープ: このカードを帰宅させる。相手の場にあるカードを最大2枚選んで手札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			# 対象なし → 自身帰宅のみ
			ctx.emit_cue(AnimationCue.find_card(ctx.source_instance_id).move().to_home())
			ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
			return SkillResult.done()
		# 選択のみ（自身の帰宅は Phase 1 で同時に演出）
		var max_pick: int = mini(2, targets.size())
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets, 1, max_pick)
	else:
		# 自身の帰宅と選択カードの返却を同時に演出
		ctx.emit_cue(AnimationCue.find_card(ctx.source_instance_id).move().to_home())
		ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
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
		ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1:
		ids.append(bs_id)
	return ids

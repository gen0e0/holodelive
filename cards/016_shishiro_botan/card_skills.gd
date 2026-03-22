extends BaseCardSkill


## なんとかしてくれる獅白ぼたん: 自宅のカードを２枚手札に加える。このカードを帰宅させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.home.size() < 2:
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate(), 2, 2)
	else:
		var chosen: Array
		if ctx.choice_result is Array:
			chosen = ctx.choice_result
		else:
			chosen = [ctx.choice_result]
		var delay: float = 0.0
		for iid in chosen:
			ctx.emit_cue(AnimationCue.find_card(iid).move().from_home().to_my_hand().with_delay(delay))
			ZoneOps.move_to_hand(ctx.state, iid, ctx.player, ctx.recorder)
			delay += 0.15
		# 自身を帰宅
		ctx.emit_cue(AnimationCue.find_card(ctx.source_instance_id).move().to_home().with_delay(delay))
		ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
		return SkillResult.done()

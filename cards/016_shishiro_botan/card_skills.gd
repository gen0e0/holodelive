extends BaseCardSkill


## なんとかしてくれる獅白ぼたん: 自宅のカードを２枚手札に加える。このカードを帰宅させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.home.size() < 2:
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate())
	elif ctx.phase == 1:
		# 1枚目を手札に
		var first: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, first, ctx.player, ctx.recorder)
		if ctx.state.home.is_empty():
			# 自宅が空なら2枚目は選べない → 自身帰宅
			ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, ctx.state.home.duplicate())
	else:
		# 2枚目を手札に
		var second: int = ctx.choice_result
		ZoneOps.move_to_hand(ctx.state, second, ctx.player, ctx.recorder)
		# 自身を帰宅
		ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
		return SkillResult.done()

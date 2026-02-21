extends BaseCardSkill


## 全ホロメン妹化計画(action): 相手と互いにサイコロを振り、
## 相手の出目以上の場合、相手の１stのカードをこちらのステージに移動する。
## 未満の場合、帰宅する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		# 自分のダイスロール
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [1, 2, 3, 4, 5, 6])
	elif ctx.phase == 1:
		ctx.data["my_roll"] = ctx.choice_result
		# 相手のダイスロール
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [1, 2, 3, 4, 5, 6])
	else:
		var my_roll: int = ctx.data.get("my_roll", 0)
		var opp_roll: int = ctx.choice_result
		if my_roll >= opp_roll:
			# 勝利: 相手1stをこちらのステージへ
			if not ctx.state.stages[opp].is_empty() and ctx.state.stages[ctx.player].size() < 3:
				var opp_first: int = ctx.state.stages[opp][0]
				ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, opp_first, ctx.recorder)
		else:
			# 敗北: 自身帰宅
			ZoneOps.move_to_home(ctx.state, ctx.source_instance_id, ctx.recorder)
		return SkillResult.done()

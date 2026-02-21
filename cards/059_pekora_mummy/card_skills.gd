extends BaseCardSkill


## ごはんよー: このカードが場に出た時、相手と３回じゃんけんをし、
## 勝利した数だけ相手ステージのカードを１stから順に帰宅させる（あいこは負け扱い）。
## その後、このカードをゲームから取り除く。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		ctx.data["wins"] = 0
		# じゃんけん1回目 (0=負け/あいこ, 1=勝ち)
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [0, 1])
	elif ctx.phase == 1:
		var wins: int = ctx.data.get("wins", 0) + (ctx.choice_result as int)
		ctx.data["wins"] = wins
		# じゃんけん2回目
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [0, 1])
	elif ctx.phase == 2:
		var wins: int = ctx.data.get("wins", 0) + (ctx.choice_result as int)
		ctx.data["wins"] = wins
		# じゃんけん3回目
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [0, 1])
	else:
		var wins: int = ctx.data.get("wins", 0) + (ctx.choice_result as int)
		# 勝利数分、相手ステージの1stから順に帰宅
		for i in range(wins):
			if ctx.state.stages[opp].is_empty():
				break
			var first: int = ctx.state.stages[opp][0]
			ZoneOps.move_to_home(ctx.state, first, ctx.recorder)
		# 自身をゲームから取り除く
		ZoneOps.remove_card(ctx.state, ctx.source_instance_id, ctx.recorder)
		return SkillResult.done()

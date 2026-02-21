extends BaseCardSkill


## 潜入捜査 Infiltration: このカードを相手の手札に加える。
## 相手の手札をランダムに１枚引き、あなたの場にプレイする（楽屋可）。場に出せない場合は帰宅。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		# 自身を相手手札に
		ZoneOps.move_to_hand(ctx.state, ctx.source_instance_id, opp, ctx.recorder)
		# 相手手札が空なら終了
		if ctx.state.hands[opp].is_empty():
			return SkillResult.done()
		# ランダムで1枚選ぶ（RANDOM_RESULT で注入）
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, ctx.state.hands[opp].duplicate())
	elif ctx.phase == 1:
		var stolen: int = ctx.choice_result
		ctx.data["stolen_card"] = stolen
		# プレイ先を選択
		var zones: Array = []
		if ctx.state.stages[ctx.player].size() < 3:
			zones.append("stage")
		if ctx.state.backstages[ctx.player] == -1:
			zones.append("backstage")
		if zones.is_empty():
			# 場に出せない → 帰宅
			ZoneOps.move_to_home(ctx.state, stolen, ctx.recorder)
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_ZONE, zones)
	else:
		var stolen: int = ctx.data.get("stolen_card", -1)
		var target: String = ctx.choice_result
		if target == "stage":
			ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, stolen, ctx.recorder)
		elif target == "backstage":
			ZoneOps.play_to_backstage_from_zone(ctx.state, ctx.player, stolen, ctx.recorder)
		return SkillResult.done()

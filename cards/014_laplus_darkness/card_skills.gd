extends BaseCardSkill


## かつもーく: 山札をめくって一番最初に出た鷹嶺ルイ(31)、博衣こより(8)、沙花叉クロヱ(18)、風真いろは(7)のうち１枚をプレイする。
const HOLOX_IDS: Array[int] = [31, 8, 18, 7]

func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		if ctx.state.stages[ctx.player].size() >= 3:
			return SkillResult.done()
		# デッキを上からめくってholoXメンバーを探す
		var found_id: int = -1
		var revealed_ids: Array = []
		for id in ctx.state.deck:
			var inst: CardInstance = ctx.state.instances[id]
			revealed_ids.append(id)
			if inst.card_id in HOLOX_IDS:
				found_id = id
				break
		if found_id == -1:
			# 見つからなかった場合、めくったカードを帰宅
			for id in revealed_ids:
				ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
			return SkillResult.done()
		# 見つかったカードをステージにプレイ、それまでのカードを帰宅
		for id in revealed_ids:
			if id != found_id:
				ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
		ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, found_id, ctx.recorder)
		return SkillResult.done()
	return SkillResult.done()

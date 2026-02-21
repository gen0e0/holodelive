extends BaseCardSkill


## 何見てンだヨ、ぺったんこ: 場にある特定12キャラを帰宅させる。
const TARGET_IDS: Array[int] = [15, 24, 22, 6, 14, 40, 41, 62, 64, 50, 57, 37]

func _skill_0(ctx: SkillContext) -> SkillResult:
	var to_remove: Array = []
	# 両プレイヤーのステージ
	for p in range(2):
		for id in ctx.state.stages[p]:
			if ctx.state.instances[id].card_id in TARGET_IDS:
				to_remove.append(id)
		var bs_id: int = ctx.state.backstages[p]
		if bs_id != -1 and ctx.state.instances[bs_id].card_id in TARGET_IDS:
			to_remove.append(bs_id)
	for id in to_remove:
		ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
	return SkillResult.done()

extends BaseCardSkill


## 伝説のドラゴン: このカードが場に出た時、両ステージのカードを全て帰宅させる（ゲスト含む）。
## その後、このカードをゲームから取り除く。
func _skill_0(ctx: SkillContext) -> SkillResult:
	# 両プレイヤーのステージと楽屋を全て帰宅
	var to_remove: Array = []
	for p in range(2):
		for id in ctx.state.stages[p]:
			if id != ctx.source_instance_id:
				to_remove.append(id)
		var bs_id: int = ctx.state.backstages[p]
		if bs_id != -1 and bs_id != ctx.source_instance_id:
			to_remove.append(bs_id)
	var delay: float = 0.0
	for id in to_remove:
		ctx.emit_cue(AnimationCue.find_card(id).move().to_home().with_delay(delay))
		delay += 0.1
		ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
	# 自身をゲームから取り除く
	ctx.emit_cue(AnimationCue.find_card(ctx.source_instance_id).move().to_home().with_delay(delay))
	ZoneOps.remove_card(ctx.state, ctx.source_instance_id, ctx.recorder)
	return SkillResult.done()

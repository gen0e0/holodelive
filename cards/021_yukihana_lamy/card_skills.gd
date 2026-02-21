extends BaseCardSkill


## やめなー: 相手は次のターン、アクション＆ゲストフェイズをスキップする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	ctx.state.turn_flags["skip_action"] = opp
	return SkillResult.done()

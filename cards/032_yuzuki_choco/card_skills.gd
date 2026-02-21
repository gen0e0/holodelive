extends BaseCardSkill


## 身体測定: 相手の場にあるゲストを１枚、オープンする。その際、プレイ時能力が発動しない。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id == -1:
		return SkillResult.done()
	if not ctx.state.instances[bs_id].face_down:
		return SkillResult.done()
	# オープン（play skill は発動しない）
	ZoneOps.open_backstage(ctx.state, opp, ctx.recorder)
	return SkillResult.done()

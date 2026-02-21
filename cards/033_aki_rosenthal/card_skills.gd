extends BaseCardSkill


## あらあらぁ: 自分の楽屋にあるカードを、ゲストにする（＝表向きにする）。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var bs_id: int = ctx.state.backstages[ctx.player]
	if bs_id == -1:
		return SkillResult.done()
	if not ctx.state.instances[bs_id].face_down:
		return SkillResult.done()
	ZoneOps.open_backstage(ctx.state, ctx.player, ctx.recorder)
	return SkillResult.done()

extends BaseCardSkill


## ドーム炊くよ！: 相手は次のターン、あなたの場のカードをプレイ時能力の対象にできない。
func _skill_0(ctx: SkillContext) -> SkillResult:
	ctx.state.turn_flags["protection"] = ctx.player
	return SkillResult.done()

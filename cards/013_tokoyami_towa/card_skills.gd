extends BaseCardSkill


## ドーム炊くよ！: 相手は次のターン、あなたの場のカードをプレイ時能力の対象にできない。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var effect := FieldEffect.new("protection", ctx.player, ctx.source_instance_id, 1)
	ctx.state.field_effects.append(effect)
	return SkillResult.done()

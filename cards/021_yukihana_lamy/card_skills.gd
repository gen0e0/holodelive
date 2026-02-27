extends BaseCardSkill


## やめなー: 相手は次のターン、アクション＆ゲストフェイズをスキップする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var effect := FieldEffect.new("skip_action", opp, ctx.source_instance_id, 1)
	ctx.state.field_effects.append(effect)
	return SkillResult.done()

extends BaseCardSkill


## わるくないよねぇ: 相手は次のターン、ステージにプレイする事ができない。
## 角巻わためが場を離れた時、この効果は消失する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var effect := FieldEffect.new("no_stage_play", opp, ctx.source_instance_id, 1)
	ctx.state.field_effects.append(effect)
	return SkillResult.done()

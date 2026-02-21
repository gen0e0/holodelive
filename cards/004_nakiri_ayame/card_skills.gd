extends BaseCardSkill


## なんも聞いとらんかった: このカードを役に含むと、先にライブ準備をしたとして扱う。
## ShowdownCalculator が参照するフラグを Modifier として付与。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var mod: Modifier = Modifier.new(Enums.ModifierType.ICON_ADD, "FIRST_READY", ctx.source_instance_id, false)
	ctx.state.instances[ctx.source_instance_id].modifiers.append(mod)
	ctx.recorder.record_modifier_add(ctx.source_instance_id, mod)
	return SkillResult.done()

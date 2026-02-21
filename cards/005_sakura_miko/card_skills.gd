extends BaseCardSkill


## サクラカゼ: このカードを役に含んで勝利した場合、２勝する。
## ShowdownCalculator / GameController が参照するフラグを Modifier として付与。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var mod: Modifier = Modifier.new(Enums.ModifierType.ICON_ADD, "DOUBLE_WIN", ctx.source_instance_id, false)
	ctx.state.instances[ctx.source_instance_id].modifiers.append(mod)
	ctx.recorder.record_modifier_add(ctx.source_instance_id, mod)
	return SkillResult.done()

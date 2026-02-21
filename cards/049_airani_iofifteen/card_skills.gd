extends BaseCardSkill


## Iofi: ライブ準備時、好きなアイコンとして扱うことができる（WILD）。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var mod: Modifier = Modifier.new(Enums.ModifierType.ICON_ADD, "WILD", ctx.source_instance_id, false)
	ctx.state.instances[ctx.source_instance_id].modifiers.append(mod)
	ctx.recorder.record_modifier_add(ctx.source_instance_id, mod)
	return SkillResult.done()


## Erofi: このカードは夏色まつりの効果の対象にならない。
## Modifier フラグとして付与。まつりのスキルがこのフラグをチェックする。
func _skill_1(ctx: SkillContext) -> SkillResult:
	var mod: Modifier = Modifier.new(Enums.ModifierType.ICON_ADD, "MATSURI_IMMUNE", ctx.source_instance_id, false)
	ctx.state.instances[ctx.source_instance_id].modifiers.append(mod)
	ctx.recorder.record_modifier_add(ctx.source_instance_id, mod)
	return SkillResult.done()

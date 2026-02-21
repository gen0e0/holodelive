extends BaseCardSkill


## Hoshimatic Project: このカードの前後に接しているカードに、一時的にVOCALを加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var adjacent: Array = _get_adjacent_ids(ctx)
	for id in adjacent:
		var mod: Modifier = Modifier.new(Enums.ModifierType.ICON_ADD, "VOCAL", ctx.source_instance_id, false)
		ctx.state.instances[id].modifiers.append(mod)
		ctx.recorder.record_modifier_add(id, mod)
	return SkillResult.done()


func _get_adjacent_ids(ctx: SkillContext) -> Array:
	var stage: Array = ctx.state.stages[ctx.player]
	var idx: int = stage.find(ctx.source_instance_id)
	if idx == -1:
		return []
	var ids: Array = []
	if idx > 0:
		ids.append(stage[idx - 1])
	if idx < stage.size() - 1:
		ids.append(stage[idx + 1])
	return ids

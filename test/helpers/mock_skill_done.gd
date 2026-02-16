extends BaseCardSkill

## Play skill that immediately returns DONE.

func _skill_0(ctx: SkillContext) -> SkillResult:
	return SkillResult.done()

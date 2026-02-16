extends BaseCardSkill

## Passive skill that can counter.

func _can_counter(_ctx: SkillContext) -> bool:
	return true


func _skill_0(ctx: SkillContext) -> SkillResult:
	return SkillResult.done()

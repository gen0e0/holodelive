extends BaseCardSkill

## Play skill that requires player choice.
## phase=0: returns WAITING_FOR_CHOICE
## phase=1: uses choice_result and returns DONE

func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, [10, 20, 30])
	# phase >= 1: choice has been made
	return SkillResult.done()

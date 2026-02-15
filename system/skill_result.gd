class_name SkillResult
extends RefCounted

enum Status { DONE, WAITING_FOR_CHOICE }

var status: Status = Status.DONE
var choice_type: Enums.ChoiceType = Enums.ChoiceType.SELECT_CARD
var valid_targets: Array = []


static func done() -> SkillResult:
	var r := SkillResult.new()
	r.status = Status.DONE
	return r


static func waiting(p_choice_type: Enums.ChoiceType, p_valid_targets: Array) -> SkillResult:
	var r := SkillResult.new()
	r.status = Status.WAITING_FOR_CHOICE
	r.choice_type = p_choice_type
	r.valid_targets = p_valid_targets
	return r

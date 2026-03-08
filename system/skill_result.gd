class_name SkillResult
extends RefCounted

enum Status { DONE, WAITING_FOR_CHOICE }

var status: Status = Status.DONE
var choice_type: Enums.ChoiceType = Enums.ChoiceType.SELECT_CARD
var valid_targets: Array = []
var select_min: int = 1  ## 最小選択枚数
var select_max: int = 1  ## 最大選択枚数


static func done() -> SkillResult:
	var r := SkillResult.new()
	r.status = Status.DONE
	return r


static func waiting(p_choice_type: Enums.ChoiceType, p_valid_targets: Array,
		p_select_min: int = 1, p_select_max: int = 1) -> SkillResult:
	var r := SkillResult.new()
	r.status = Status.WAITING_FOR_CHOICE
	r.choice_type = p_choice_type
	r.valid_targets = p_valid_targets
	r.select_min = p_select_min
	r.select_max = p_select_max
	return r

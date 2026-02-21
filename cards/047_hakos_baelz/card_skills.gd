extends BaseCardSkill


## カオスそのもの: 相手の場にあるカードを１枚選び、このカードと場所を入れ替える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		_swap_positions(ctx, ctx.source_instance_id, chosen)
		return SkillResult.done()


func _get_opp_field_ids(ctx: SkillContext) -> Array:
	var opp: int = 1 - ctx.player
	var ids: Array = []
	for id in ctx.state.stages[opp]:
		ids.append(id)
	var bs_id: int = ctx.state.backstages[opp]
	if bs_id != -1:
		ids.append(bs_id)
	return ids


func _swap_positions(ctx: SkillContext, card_a: int, card_b: int) -> void:
	var opp: int = 1 - ctx.player
	# card_a の位置を特定
	var a_zone: String = ""
	var a_stage_idx: int = -1
	var a_idx: int = ctx.state.stages[ctx.player].find(card_a)
	if a_idx != -1:
		a_zone = "stage"
		a_stage_idx = a_idx
	elif ctx.state.backstages[ctx.player] == card_a:
		a_zone = "backstage"

	# card_b の位置を特定
	var b_zone: String = ""
	var b_stage_idx: int = -1
	var b_idx: int = ctx.state.stages[opp].find(card_b)
	if b_idx != -1:
		b_zone = "stage"
		b_stage_idx = b_idx
	elif ctx.state.backstages[opp] == card_b:
		b_zone = "backstage"

	# 両方を一旦除去
	if a_zone == "stage":
		ctx.state.stages[ctx.player].erase(card_a)
	elif a_zone == "backstage":
		ctx.state.backstages[ctx.player] = -1

	if b_zone == "stage":
		ctx.state.stages[opp].erase(card_b)
	elif b_zone == "backstage":
		ctx.state.backstages[opp] = -1

	# card_a を card_b のいた場所に配置（相手側）
	if b_zone == "stage":
		ctx.state.stages[opp].insert(mini(b_stage_idx, ctx.state.stages[opp].size()), card_a)
		ctx.state.instances[card_a].face_down = false
	elif b_zone == "backstage":
		ctx.state.backstages[opp] = card_a
		ctx.state.instances[card_a].face_down = ctx.state.instances[card_a].face_down

	# card_b を card_a のいた場所に配置（自分側）
	if a_zone == "stage":
		ctx.state.stages[ctx.player].insert(mini(a_stage_idx, ctx.state.stages[ctx.player].size()), card_b)
		ctx.state.instances[card_b].face_down = false
	elif a_zone == "backstage":
		ctx.state.backstages[ctx.player] = card_b

	ctx.recorder.record_card_move(card_a, a_zone, 0, b_zone, 0)
	ctx.recorder.record_card_move(card_b, b_zone, 0, a_zone, 0)

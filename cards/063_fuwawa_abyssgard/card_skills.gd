extends BaseCardSkill


## 番犬: このカードがステージに出たとき、山札、自宅、場、自分の手札からモココ(card_id=64)をステージに出す。
const TARGET_CARD_ID: int = 64

func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.state.stages[ctx.player].size() >= 3:
		return SkillResult.done()
	var found_id: int = _find_card_in_zones(ctx, TARGET_CARD_ID)
	if found_id == -1:
		return SkillResult.done()
	ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, found_id, ctx.recorder)
	return SkillResult.done()


func _find_card_in_zones(ctx: SkillContext, target_card_id: int) -> int:
	# デッキから探す
	for id in ctx.state.deck:
		if ctx.state.instances[id].card_id == target_card_id:
			return id
	# 自宅から探す
	for id in ctx.state.home:
		if ctx.state.instances[id].card_id == target_card_id:
			return id
	# 自分のステージから探す（自分自身を除く）
	for id in ctx.state.stages[ctx.player]:
		if id == ctx.source_instance_id:
			continue
		if ctx.state.instances[id].card_id == target_card_id:
			return id
	# 相手のステージから探す
	var opp: int = 1 - ctx.player
	for id in ctx.state.stages[opp]:
		if ctx.state.instances[id].card_id == target_card_id:
			return id
	# 楽屋から探す
	for p in range(2):
		var bs_id: int = ctx.state.backstages[p]
		if bs_id != -1 and ctx.state.instances[bs_id].card_id == target_card_id:
			return bs_id
	# 自分の手札から探す
	for id in ctx.state.hands[ctx.player]:
		if ctx.state.instances[id].card_id == target_card_id:
			return id
	return -1

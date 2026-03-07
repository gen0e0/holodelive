extends BaseCardSkill


## 番犬: このカードがステージに出たとき、山札、自宅、場、自分の手札からモココ(card_id=64)をステージに出す。
const TARGET_CARD_ID: int = 64

func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.state.stages[ctx.player].size() >= 3:
		return SkillResult.done()
	var result: Dictionary = _find_card_in_zones(ctx, TARGET_CARD_ID)
	var found_id: int = result.get("id", -1)
	if found_id == -1:
		return SkillResult.done()
	var cue: AnimationCue = _make_cue(found_id, result["zone"], ctx)
	if cue != null:
		ctx.emit_cue(cue)
	ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, found_id, ctx.recorder)
	return SkillResult.done()


func _make_cue(iid: int, zone: String, ctx: SkillContext) -> AnimationCue:
	match zone:
		"deck":
			return AnimationCue.make_card(iid).move().from_deck().to_my_stage()
		"home":
			return AnimationCue.find_card(iid).move().from_home().to_my_stage()
		"my_hand":
			return AnimationCue.make_card(iid).move().from_my_hand().to_my_stage()
		"my_stage", "my_backstage":
			return AnimationCue.find_card(iid).move().to_my_stage()
		"op_stage":
			return AnimationCue.find_card(iid).move().from_op_stage().to_my_stage()
		"op_backstage":
			return AnimationCue.find_card(iid).move().from_op_backstage().to_my_stage()
	return null


func _find_card_in_zones(ctx: SkillContext, target_card_id: int) -> Dictionary:
	# デッキから探す
	for id in ctx.state.deck:
		if ctx.state.instances[id].card_id == target_card_id:
			return {"id": id, "zone": "deck"}
	# 自宅から探す
	for id in ctx.state.home:
		if ctx.state.instances[id].card_id == target_card_id:
			return {"id": id, "zone": "home"}
	# 自分のステージから探す（自分自身を除く）
	for id in ctx.state.stages[ctx.player]:
		if id == ctx.source_instance_id:
			continue
		if ctx.state.instances[id].card_id == target_card_id:
			return {"id": id, "zone": "my_stage"}
	# 相手のステージから探す
	var opp: int = 1 - ctx.player
	for id in ctx.state.stages[opp]:
		if ctx.state.instances[id].card_id == target_card_id:
			return {"id": id, "zone": "op_stage"}
	# 楽屋から探す
	for p in range(2):
		var bs_id: int = ctx.state.backstages[p]
		if bs_id != -1 and ctx.state.instances[bs_id].card_id == target_card_id:
			var zone: String = "my_backstage" if p == ctx.player else "op_backstage"
			return {"id": bs_id, "zone": zone}
	# 自分の手札から探す
	for id in ctx.state.hands[ctx.player]:
		if ctx.state.instances[id].card_id == target_card_id:
			return {"id": id, "zone": "my_hand"}
	return {"id": -1, "zone": ""}

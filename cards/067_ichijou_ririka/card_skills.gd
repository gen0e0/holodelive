extends BaseCardSkill


## 酒持ってこーい: 山札の上から４枚をめくり、最初に出たALCOHOLのカードを１枚、プレイする。
## それ以外のカードや、出なかった場合は残ったカードを全て帰宅させる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var count: int = mini(4, ctx.state.deck.size())
		if count == 0:
			return SkillResult.done()
		var revealed: Array = []
		for i in range(count):
			revealed.append(ctx.state.deck[i])
		# ALCOHOLアイコンを持つカードを探す
		var found_id: int = -1
		for id in revealed:
			var inst: CardInstance = ctx.state.instances[id]
			var card_def: CardDef = ctx.registry.get_card(inst.card_id)
			if not card_def:
				continue
			var icons: Array[String] = inst.effective_icons(card_def)
			if icons.has("ALCOHOL"):
				found_id = id
				break
		if found_id == -1:
			# ALCOHOLなし: 全て帰宅
			for id in revealed:
				ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
			return SkillResult.done()
		# ALCOHOLカードをプレイ、残りを帰宅
		for id in revealed:
			if id != found_id:
				ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
		# プレイ先を選択
		ctx.data["found_card"] = found_id
		var zones: Array = []
		if ctx.state.stages[ctx.player].size() < 3:
			zones.append("stage")
		if ctx.state.backstages[ctx.player] == -1:
			zones.append("backstage")
		if zones.is_empty():
			ZoneOps.move_to_home(ctx.state, found_id, ctx.recorder)
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_ZONE, zones)
	else:
		var found_card: int = ctx.data.get("found_card", -1)
		var target: String = ctx.choice_result
		if target == "stage":
			ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, found_card, ctx.recorder)
		elif target == "backstage":
			ZoneOps.play_to_backstage_from_zone(ctx.state, ctx.player, found_card, ctx.recorder)
		return SkillResult.done()

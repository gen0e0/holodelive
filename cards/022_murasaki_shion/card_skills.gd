extends BaseCardSkill


## 無軌道雑談: あなたと相手の手札を併せてシャッフルし、同枚数配り直す。
## RANDOM_RESULT で配り直しの順序を決定する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var my_count: int = ctx.state.hands[ctx.player].size()
	var opp_count: int = ctx.state.hands[opp].size()
	if my_count + opp_count == 0:
		return SkillResult.done()

	if ctx.phase == 0:
		var all_cards: Array = ctx.state.hands[ctx.player].duplicate()
		all_cards.append_array(ctx.state.hands[opp])
		ctx.data["my_count"] = my_count
		ctx.data["opp_count"] = opp_count
		ctx.data["all_cards"] = all_cards
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, all_cards.duplicate())
	else:
		var all_cards: Array = ctx.data.get("all_cards", [])
		var saved_my_count: int = ctx.data.get("my_count", 0)
		var saved_opp_count: int = ctx.data.get("opp_count", 0)
		# choice_result を先頭にローテーションしてシャッフル代替
		var chosen: int = ctx.choice_result
		var chosen_idx: int = all_cards.find(chosen)
		if chosen_idx > 0:
			var rotated: Array = all_cards.slice(chosen_idx)
			rotated.append_array(all_cards.slice(0, chosen_idx))
			all_cards = rotated
		ctx.state.hands[ctx.player].clear()
		ctx.state.hands[opp].clear()
		for i in range(saved_my_count):
			if i < all_cards.size():
				ctx.state.hands[ctx.player].append(all_cards[i])
				ctx.recorder.record_card_move(all_cards[i], "hand", -1, "hand", i)
		for i in range(saved_opp_count):
			var idx: int = saved_my_count + i
			if idx < all_cards.size():
				ctx.state.hands[opp].append(all_cards[idx])
				ctx.recorder.record_card_move(all_cards[idx], "hand", -1, "hand", i)
		return SkillResult.done()

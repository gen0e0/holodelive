extends BaseCardSkill


## おあとがよろしいようで: 山札の上から3枚を見て、その後好きな順番で山札の上に置く。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var deck_size: int = ctx.state.deck.size()
		if deck_size < 2:
			return SkillResult.done()
		var count: int = mini(3, deck_size)
		var cards: Array = []
		for i in range(count):
			cards.append(ctx.state.deck[i])
		ctx.data["original_cards"] = cards.duplicate()
		ctx.data["ordered"] = []
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, cards)
	elif ctx.phase == 1:
		# 1番目（一番上）に置くカードを選択
		var first: int = ctx.choice_result
		var ordered: Array = ctx.data.get("ordered", [])
		ordered.append(first)
		ctx.data["ordered"] = ordered
		var original: Array = ctx.data.get("original_cards", [])
		var remaining: Array = []
		for id in original:
			if not ordered.has(id):
				remaining.append(id)
		if remaining.size() <= 1:
			# 残り1枚は自動的に最後
			ordered.append_array(remaining)
			ctx.data["ordered"] = ordered
			_reorder_deck_top(ctx)
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, remaining)
	else:
		# 2番目を選択、残りが3番目
		var second: int = ctx.choice_result
		var ordered: Array = ctx.data.get("ordered", [])
		ordered.append(second)
		var original: Array = ctx.data.get("original_cards", [])
		for id in original:
			if not ordered.has(id):
				ordered.append(id)
		ctx.data["ordered"] = ordered
		_reorder_deck_top(ctx)
		return SkillResult.done()


func _reorder_deck_top(ctx: SkillContext) -> void:
	var ordered: Array = ctx.data.get("ordered", [])
	# デッキ上部から元のカードを除去
	for id in ordered:
		ctx.state.deck.erase(id)
	# ordered の順番でデッキ先頭に挿入（逆順で push_front）
	for i in range(ordered.size() - 1, -1, -1):
		ctx.state.deck.push_front(ordered[i])
		ctx.recorder.record_card_move(ordered[i], "deck", -1, "deck", 0)

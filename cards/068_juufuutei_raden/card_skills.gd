extends BaseCardSkill


## おあとがよろしいようで: 山札の上から3枚を見て、好きな順番で山札の上に置く。
## 選択順 = デッキトップからの順（1番目に選んだカードが次にドローされる）。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var deck_size: int = ctx.state.deck.size()
		if deck_size < 2:
			return SkillResult.done()
		var count: int = mini(3, deck_size)
		var cards: Array = []
		for i in range(count):
			cards.append(ctx.state.deck[i])
		ctx.data["top_cards"] = cards.duplicate()
		# 演出は DeckReorderSelector が担当（デッキ→スロットへ飛ばす）
		return SkillResult.waiting(
			Enums.ChoiceType.SELECT_CARD, cards, count, count, "deck_reorder")
	else:
		# 選択順でデッキトップに並べ替え
		var chosen: Variant = ctx.choice_result
		var ordered: Array = chosen if chosen is Array else [chosen]
		# デッキ上部から元のカードを除去
		for id in ordered:
			ctx.state.deck.erase(id)
		# ordered の順番でデッキ先頭に挿入（逆順で push_front）
		# 演出は DeckReorderSelector が担当（スロット→デッキへ戻す）
		for i in range(ordered.size() - 1, -1, -1):
			ctx.state.deck.push_front(ordered[i])
			ctx.recorder.record_card_move(ordered[i], "deck", -1, "deck", 0)
		return SkillResult.done()

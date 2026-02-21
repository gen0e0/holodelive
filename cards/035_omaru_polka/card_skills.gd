extends BaseCardSkill


## ポルカおるか？(play): 山札から1枚カードを引き、手札に加える。その後、手札から1枚山札の上に置く。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		var hand: Array = ctx.state.hands[ctx.player]
		if hand.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_deck_top(ctx.state, chosen, ctx.recorder)
		return SkillResult.done()


## ポルカおらんか？(action): このカードを山札の一番下のカードと入れ替え、同じ場所にプレイする。
func _skill_1(ctx: SkillContext) -> SkillResult:
	if ctx.state.deck.is_empty():
		return SkillResult.done()
	# 元の位置を記録
	var zone: Dictionary = ctx.state.find_zone(ctx.source_instance_id)
	var was_on_stage: bool = zone.get("zone", "") == "stage"
	var player: int = ctx.player
	# デッキ最下部のカードを取得
	var bottom_id: int = ctx.state.deck.back()
	# 自身をデッキ最下部に移動
	ZoneOps.move_to_deck_bottom(ctx.state, ctx.source_instance_id, ctx.recorder)
	# デッキ最下部だったカードを元の位置にプレイ
	if was_on_stage:
		ZoneOps.play_to_stage_from_zone(ctx.state, player, bottom_id, ctx.recorder)
	else:
		ZoneOps.play_to_backstage_from_zone(ctx.state, player, bottom_id, ctx.recorder)
	return SkillResult.done()

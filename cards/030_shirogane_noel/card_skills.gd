extends BaseCardSkill


## 入口の女: 山札から2枚引いて手札に加え、その後、手札から2枚選び好きな順番で山札に戻す。
## choice_result は [slot_a_iid, slot_b_iid]。slot_a がデッキトップ。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		# 2枚ドロー
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		var hand: Array = ctx.state.hands[ctx.player]
		if hand.size() < 2:
			return SkillResult.done()
		# ドロー2枚のアニメーション
		ctx.emit_cue(AnimationCue.make_card(hand[-2]).move().from_deck().to_my_hand())
		ctx.emit_cue(AnimationCue.make_card(hand[-1]).move().from_deck().to_my_hand().with_delay(0.15))
		return SkillResult.waiting(
			Enums.ChoiceType.SELECT_CARD, hand.duplicate(), 2, 2, "deck_return")
	else:
		var chosen: Array = ctx.choice_result
		var top_iid: int = chosen[0]   # slot A = デッキトップ
		var second_iid: int = chosen[1] # slot B = 2番目
		# B を先に積み、A をその上に積む
		ctx.emit_cue(AnimationCue.find_card(second_iid).move().from_my_hand().to_deck())
		ZoneOps.move_to_deck_top(ctx.state, second_iid, ctx.recorder)
		ctx.emit_cue(AnimationCue.find_card(top_iid).move().from_my_hand().to_deck().with_delay(0.15))
		ZoneOps.move_to_deck_top(ctx.state, top_iid, ctx.recorder)
		return SkillResult.done()

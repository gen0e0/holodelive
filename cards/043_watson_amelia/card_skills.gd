extends BaseCardSkill


## グレムリンノイズ: あなたと相手の手札を、交換する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	var my_hand: Array = ctx.state.hands[ctx.player].duplicate()
	var opp_hand: Array = ctx.state.hands[opp].duplicate()

	# 演出: 自分の手札→相手へ、相手の手札→自分へ（同時発火、delay でスタガー）
	var delay: float = 0.0
	for id in my_hand:
		ctx.emit_cue(AnimationCue.find_card(id).move().from_my_hand().to_op_hand().face_up(false).with_delay(delay))
		delay += 0.1
	for id in opp_hand:
		ctx.emit_cue(AnimationCue.make_card(id).move().from_op_hand().to_my_hand().with_delay(delay))
		delay += 0.1

	ctx.state.hands[ctx.player].clear()
	ctx.state.hands[opp].clear()
	for i in range(opp_hand.size()):
		ctx.state.hands[ctx.player].append(opp_hand[i])
		ctx.recorder.record_card_move(opp_hand[i], "hand", i, "hand", ctx.state.hands[ctx.player].size() - 1)
	for i in range(my_hand.size()):
		ctx.state.hands[opp].append(my_hand[i])
		ctx.recorder.record_card_move(my_hand[i], "hand", i, "hand", ctx.state.hands[opp].size() - 1)
	return SkillResult.done()

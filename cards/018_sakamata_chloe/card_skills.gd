extends BaseCardSkill


## 人生リセットボタンぽちー: あなたは手札を全て帰宅させ、3枚ドローする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var delay: float = 0.0
	var hand_ids: Array = ctx.state.hands[ctx.player].duplicate()
	for id in hand_ids:
		ctx.emit_cue(AnimationCue.find_card(id).move().from_my_hand().to_home().with_delay(delay))
		delay += 0.1
		ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
	for i in range(3):
		var drawn_iid: int = ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		if drawn_iid >= 0:
			ctx.emit_cue(AnimationCue.make_card(drawn_iid).move().from_deck().to_my_hand().with_delay(delay))
			delay += 0.1
	return SkillResult.done()

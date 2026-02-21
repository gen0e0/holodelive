extends BaseCardSkill


## 人生リセットボタンぽちー: あなたは手札を全て帰宅させ、3枚ドローする。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var hand_ids: Array = ctx.state.hands[ctx.player].duplicate()
	for id in hand_ids:
		ZoneOps.move_to_home(ctx.state, id, ctx.recorder)
	for i in range(3):
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
	return SkillResult.done()

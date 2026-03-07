extends BaseCardSkill


## じゃじゃーん！青くんでした！: このカードは直ちに相手のステージに移動する。
## その後、あなたは山札から１枚引いて手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player
	if ctx.state.stages[opp].size() >= 3:
		return SkillResult.done()
	ctx.emit_cue(AnimationCue.find_card(ctx.source_instance_id).move().to_op_stage())
	ZoneOps.play_to_stage_from_zone(ctx.state, opp, ctx.source_instance_id, ctx.recorder)
	var drawn_iid: int = ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
	if drawn_iid >= 0:
		ctx.emit_cue(AnimationCue.make_card(drawn_iid).move().from_deck().to_my_hand().with_delay(0.2))
	return SkillResult.done()

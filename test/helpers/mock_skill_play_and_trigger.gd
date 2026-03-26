extends BaseCardSkill

## Play skill that places a card from hand to stage and triggers its play skill.
## Expects ctx.data["target_iid"] to be set by the test.

func _skill_0(ctx: SkillContext) -> SkillResult:
	var target_iid: int = ctx.data.get("target_iid", -1)
	if target_iid < 0:
		return SkillResult.done()
	ZoneOps.play_to_stage_from_zone(ctx.state, ctx.player, target_iid, ctx.recorder)
	return SkillResult.done_and_trigger_play(target_iid, ctx.player)

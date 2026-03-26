extends BaseCardSkill


## ごはんよー: このカードが場に出た時、相手と３回じゃんけんをし、
## 勝利した数だけ相手ステージのカードを１stから順に帰宅させる（あいこは負け扱い）。
## その後、このカードをゲームから取り除く。
const HANDS: Array = ["G", "P", "C"]

func _skill_0(ctx: SkillContext) -> SkillResult:
	var opp: int = 1 - ctx.player

	if ctx.phase == 0:
		# ラウンド1: 初期化して選択を送る
		ctx.data["wins"] = 0
		return _make_janken_choice(ctx, 1, 0, "", "")

	# Phase 1-3: 前ラウンドの結果処理
	var my_hand: String = ctx.choice_results[0] if ctx.choice_results.size() > 0 else "G"
	var opp_hand: String = ctx.choice_results[1] if ctx.choice_results.size() > 1 else "G"
	var wins: int = ctx.data.get("wins", 0)
	if _is_win(my_hand, opp_hand):
		wins += 1
	ctx.data["wins"] = wins

	var round_played: int = ctx.phase  # phase 1=R1完了, 2=R2完了, 3=R3完了

	if round_played < 3:
		# 次のラウンドへ
		return _make_janken_choice(ctx, round_played + 1, wins, my_hand, opp_hand)

	# 全3ラウンド完了 → 勝利数分帰宅 + 自身除外
	var delay: float = 0.0
	for i in range(wins):
		if ctx.state.stages[opp].is_empty():
			break
		var first: int = ctx.state.stages[opp][0]
		ctx.emit_cue(AnimationCue.find_card(first).move().to_home().with_delay(delay))
		ZoneOps.move_to_home(ctx.state, first, ctx.recorder)
		delay += 0.15
	# 自身をゲームから取り除く
	ctx.emit_cue(AnimationCue.find_card(ctx.source_instance_id).move().to_home()
		.with_delay(delay))
	ZoneOps.remove_card(ctx.state, ctx.source_instance_id, ctx.recorder)
	return SkillResult.done()


func _make_janken_choice(ctx: SkillContext, round_num: int, wins: int,
		my_last: String, opp_last: String) -> SkillResult:
	var opp: int = 1 - ctx.player
	var hint_for_me: String = "janken:%d:%d:%s:%s" % [round_num, wins, my_last, opp_last]
	var hint_for_opp: String = "janken:%d:%d:%s:%s" % [round_num, wins, opp_last, my_last]
	return SkillResult.waiting_choices([
		{
			"target_player": ctx.player,
			"choice_type": Enums.ChoiceType.SELECT_CARD,
			"valid_targets": HANDS.duplicate(),
			"ui_hint": hint_for_me,
		},
		{
			"target_player": opp,
			"choice_type": Enums.ChoiceType.SELECT_CARD,
			"valid_targets": HANDS.duplicate(),
			"ui_hint": hint_for_opp,
		},
	])


func _is_win(my_hand: String, opp_hand: String) -> bool:
	return (my_hand == "G" and opp_hand == "C") or \
		   (my_hand == "P" and opp_hand == "G") or \
		   (my_hand == "C" and opp_hand == "P")

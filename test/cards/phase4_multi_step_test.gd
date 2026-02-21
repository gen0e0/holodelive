extends GdUnitTestSuite

## Phase 4: 複数段階 Play スキル テスト

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	return (load(path) as GDScript).new()


# --- 030 白銀ノエル: 入口の女（2ドロー→2枚デッキ上へ）---

func test_030_noel_draw_and_return() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(30, "ノエル", ["DUELIST"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(30, _load_skill("res://cards/030_shirogane_noel/card_skills.gd"))

	for i in range(4):
		H.place_in_deck_top(state, 30)
	var inst_id: int = H.place_on_stage(state, 0, 30)

	# Phase 0: 2枚ドロー → 手札から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(state.hands[0].size()).is_equal(2)
	assert_int(state.deck.size()).is_equal(2)

	var h0: int = state.hands[0][0]
	var h1: int = state.hands[0][1]

	# Phase 1: 1枚目をデッキ上に戻す
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, h0, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 2枚目をデッキ上に戻す
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, h1, DiffRecorder.new())
	result = sr.get_skill(30).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(0)
	assert_int(state.deck.size()).is_equal(4)
	assert_int(state.deck[0]).is_equal(h1)  # 最後に戻したのがトップ


# --- 035 ポルカ play: ポルカおるか？（1ドロー→1枚デッキ上）---

func test_035_polka_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(35, "ポルカ", ["TRICKSTER"], ["HOT"], [H.play_skill(), H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(35, _load_skill("res://cards/035_omaru_polka/card_skills.gd"))

	H.place_in_deck_top(state, 35)
	var hand_card: int = H.place_in_hand(state, 0, 35)
	var inst_id: int = H.place_on_stage(state, 0, 35)

	# Phase 0: ドロー → 手札から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(35).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(state.hands[0].size()).is_equal(2)

	# Phase 1: 元の手札カードをデッキ上に戻す
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	result = sr.get_skill(35).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck[0]).is_equal(hand_card)


# --- 035 ポルカ action: ポルカおらんか？（デッキ最下部と交換）---

func test_035_polka_action_swap() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(35, "ポルカ", ["TRICKSTER"], ["HOT"], [H.play_skill(), H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(35, _load_skill("res://cards/035_omaru_polka/card_skills.gd"))

	var bottom_card: int = H.place_in_deck_bottom(state, 35)
	var inst_id: int = H.place_on_stage(state, 0, 35)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(35).execute_skill(ctx, 1)  # skill_index=1
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# ポルカはデッキ最下部に、元のデッキ最下部カードがステージに
	assert_bool(state.stages[0].has(bottom_card)).is_true()
	assert_int(state.deck.back()).is_equal(inst_id)


# --- 025 兎田ぺこら: 豪運うさぎ（手札⇔デッキ上→プレイ）---

func test_025_pekora_swap_and_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(25, "ぺこら", ["CHARISMA"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(25, _load_skill("res://cards/025_usada_pekora/card_skills.gd"))

	var deck_top: int = H.place_in_deck_top(state, 25)
	var hand_card: int = H.place_in_hand(state, 0, 25)
	var inst_id: int = H.place_on_stage(state, 0, 25)

	# Phase 0: 手札から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(25).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 交換してプレイ先選択
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(25).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(state.hands[0].has(deck_top)).is_true()

	# Phase 2: ステージにプレイ
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"drawn_card": deck_top}
	result = sr.get_skill(25).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(deck_top)).is_true()


# --- 026 宝鐘マリン: マリ箱（相手場→相手手札、自手札→楽屋）---

func test_026_marine_steal_and_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(26, "マリン", ["OTAKU", "SEXY"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(26, _load_skill("res://cards/026_houshou_marine/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 26)
	var my_hand: int = H.place_in_hand(state, 0, 26)
	var inst_id: int = H.place_on_stage(state, 0, 26)

	# Phase 0: 相手場から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(26).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 相手カードを相手手札に → 自手札から楽屋へ選択
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(26).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp_card)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 手札から楽屋にプレイ
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, my_hand, DiffRecorder.new())
	result = sr.get_skill(26).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.backstages[0]).is_equal(my_hand)


# --- 028 戌神ころね: おらよ（相手場2枚→相手手札）---

func test_028_korone_return_two() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(28, "ころね", ["ENJOY"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(28, _load_skill("res://cards/028_inugami_korone/card_skills.gd"))

	var opp1: int = H.place_on_stage(state, 1, 28)
	var opp2: int = H.place_on_stage(state, 1, 28)
	var inst_id: int = H.place_on_stage(state, 0, 28)

	# Phase 0
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(28).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 1枚目を相手手札に
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	result = sr.get_skill(28).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 2枚目を相手手札に
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp2, DiffRecorder.new())
	result = sr.get_skill(28).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(opp2)).is_true()


# --- 052 アユンダ・リス: ALiCE&u（デッキ上2枚→1枚自分、1枚相手）---

func test_052_risu_split() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(52, "リス", ["ENJOY"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(52, _load_skill("res://cards/052_ayunda_risu/card_skills.gd"))

	var top1: int = H.place_in_deck_top(state, 52)
	var top2: int = H.place_in_deck_top(state, 52)
	# top2 is now deck[0], top1 is deck[1]
	var inst_id: int = H.place_on_stage(state, 0, 52)

	# Phase 0: デッキ上2枚から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(52).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: top2 を選択→自分の手札、top1→相手の手札
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, top2, DiffRecorder.new())
	ctx.data = {"card1": top2, "card2": top1}
	result = sr.get_skill(52).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(top2)).is_true()
	assert_bool(state.hands[1].has(top1)).is_true()


# --- 068 儒烏風亭らでん: おあとがよろしいようで（デッキ上3枚並べ替え）---

func test_068_raden_reorder() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(68, "らでん", ["OTAKU"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(68, _load_skill("res://cards/068_juufuutei_raden/card_skills.gd"))

	var c1: int = H.place_in_deck_top(state, 68)
	var c2: int = H.place_in_deck_top(state, 68)
	var c3: int = H.place_in_deck_top(state, 68)
	# deck = [c3, c2, c1]
	var inst_id: int = H.place_on_stage(state, 0, 68)

	# Phase 0: 3枚表示
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: c1 を一番上に
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, c1, DiffRecorder.new())
	ctx.data = {"original_cards": [c3, c2, c1], "ordered": []}
	result = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: c3 を2番目に（c2 が3番目）
	var ordered_so_far: Array = ctx.data.get("ordered", [c1])
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, c3, DiffRecorder.new())
	ctx.data = {"original_cards": [c3, c2, c1], "ordered": ordered_so_far}
	result = sr.get_skill(68).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# デッキ上から c1, c3, c2 の順
	assert_int(state.deck[0]).is_equal(c1)
	assert_int(state.deck[1]).is_equal(c3)
	assert_int(state.deck[2]).is_equal(c2)

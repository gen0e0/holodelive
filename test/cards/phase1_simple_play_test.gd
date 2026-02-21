extends GdUnitTestSuite

## Phase 1: シンプル Play スキル テスト

var H := SkillTestHelper


# --- 009 ロボ子さん: こーせーのー（1枚ドロー）---

func test_009_roboco_draw_one() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(9, "ロボ子さん", ["SEXY"], ["LOVELY"], [H.play_skill("こーせーのー")])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(9, load("res://cards/009_roboco/card_skills.gd").new())

	# デッキに3枚、手札に0枚
	H.place_in_deck_top(state, 9)
	H.place_in_deck_top(state, 9)
	H.place_in_deck_top(state, 9)
	var inst_id: int = H.place_on_stage(state, 0, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var skill: BaseCardSkill = sr.get_skill(9)
	var result: SkillResult = skill.execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)
	assert_int(state.deck.size()).is_equal(2)

func test_009_roboco_empty_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(9, "ロボ子さん", ["SEXY"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(9, load("res://cards/009_roboco/card_skills.gd").new())
	var inst_id: int = H.place_on_stage(state, 0, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var skill: BaseCardSkill = sr.get_skill(9)
	var result: SkillResult = skill.execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(0)


# --- 050 クレイジー・オリー: ゾンビパーティ（デッキ最下部→手札）---

func test_050_ollie_bottom_draw() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(50, "オリー", ["OTAKU", "INTEL"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(50, load("res://cards/050_kureiji_ollie/card_skills.gd").new())

	var top_id: int = H.place_in_deck_top(state, 50)
	var bottom_id: int = H.place_in_deck_bottom(state, 50)
	var inst_id: int = H.place_on_stage(state, 0, 50)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(50).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(bottom_id)).is_true()
	assert_int(state.deck.size()).is_equal(1)
	assert_int(state.deck[0]).is_equal(top_id)

func test_050_ollie_empty_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(50, "オリー", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(50, load("res://cards/050_kureiji_ollie/card_skills.gd").new())
	var inst_id: int = H.place_on_stage(state, 0, 50)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(50).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(0)


# --- 018 沙花叉クロヱ: 人生リセットボタン（手札全帰宅→3ドロー）---

func test_018_chloe_reset() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(18, "クロヱ", ["DUELIST", "SEXY"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(18, load("res://cards/018_sakamata_chloe/card_skills.gd").new())

	# 手札2枚、デッキ5枚
	var h1: int = H.place_in_hand(state, 0, 18)
	var h2: int = H.place_in_hand(state, 0, 18)
	for i in range(5):
		H.place_in_deck_top(state, 18)
	var inst_id: int = H.place_on_stage(state, 0, 18)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(18).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(3)
	assert_bool(state.home.has(h1)).is_true()
	assert_bool(state.home.has(h2)).is_true()
	assert_int(state.deck.size()).is_equal(2)


# --- 010 姫森ルーナ: くせえのら（相手手札ランダム1枚帰宅）---

func test_010_luna_random_discard() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(10, "ルーナ", ["ALCOHOL", "SEISO"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var controller: GameController = env.controller
	var sr: SkillRegistry = env.skill_registry
	sr.register(10, load("res://cards/010_himemori_luna/card_skills.gd").new())

	# 相手手札に1枚
	var opp_card: int = H.place_in_hand(state, 1, 10)
	var inst_id: int = H.place_on_stage(state, 0, 10)

	# Phase 0: RANDOM_RESULT 待ち
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(10).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_int(result.choice_type).is_equal(Enums.ChoiceType.RANDOM_RESULT)

	# Phase 1: 選択結果で帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(10).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(opp_card)).is_false()
	assert_bool(state.home.has(opp_card)).is_true()

func test_010_luna_empty_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(10, "ルーナ", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(10, load("res://cards/010_himemori_luna/card_skills.gd").new())
	var inst_id: int = H.place_on_stage(state, 0, 10)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(10).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 017 大神ミオ: Big God Mio-n（相手手札全帰宅→2ドロー）---

func test_017_mio_discard_all_draw_two() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(17, "ミオ", ["REACTION", "INTEL"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(17, load("res://cards/017_ookami_mio/card_skills.gd").new())

	var opp1: int = H.place_in_hand(state, 1, 17)
	var opp2: int = H.place_in_hand(state, 1, 17)
	for i in range(3):
		H.place_in_deck_top(state, 17)
	var inst_id: int = H.place_on_stage(state, 0, 17)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(17).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp1)).is_true()
	assert_bool(state.home.has(opp2)).is_true()
	assert_int(state.hands[1].size()).is_equal(2)
	assert_int(state.deck.size()).is_equal(1)


# --- 043 ワトソン・アメリア: グレムリンノイズ（手札交換）---

func test_043_amelia_hand_swap() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(43, "アメリア", ["ENJOY", "TRICKSTER"], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(43, load("res://cards/043_watson_amelia/card_skills.gd").new())

	var my1: int = H.place_in_hand(state, 0, 43)
	var my2: int = H.place_in_hand(state, 0, 43)
	var opp1: int = H.place_in_hand(state, 1, 43)
	var inst_id: int = H.place_on_stage(state, 0, 43)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(43).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# P0 now has opp's card, P1 has my cards
	assert_int(state.hands[0].size()).is_equal(1)
	assert_bool(state.hands[0].has(opp1)).is_true()
	assert_int(state.hands[1].size()).is_equal(2)
	assert_bool(state.hands[1].has(my1)).is_true()
	assert_bool(state.hands[1].has(my2)).is_true()


# --- 036 YAGOO: お茶会（相手手札からランダム2枚奪取、1枚残す）---

func test_036_yagoo_steal_two() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(36, "YAGOO", [], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(36, load("res://cards/036_yagoo/card_skills.gd").new())

	var opp1: int = H.place_in_hand(state, 1, 36)
	var opp2: int = H.place_in_hand(state, 1, 36)
	var opp3: int = H.place_in_hand(state, 1, 36)
	var inst_id: int = H.place_on_stage(state, 0, 36)

	# Phase 0: RANDOM_RESULT 待ち
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(36).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 1枚目奪取
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(36).execute_skill(ctx, 0)
	assert_bool(state.hands[0].has(opp1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 2枚目奪取（opp3 を指定。opp2 は1枚残す用）
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp3, DiffRecorder.new())
	result = sr.get_skill(36).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(opp3)).is_true()
	assert_int(state.hands[1].size()).is_equal(1)
	assert_bool(state.hands[1].has(opp2)).is_true()

func test_036_yagoo_opponent_one_card() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(36, "YAGOO", [], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(36, load("res://cards/036_yagoo/card_skills.gd").new())

	H.place_in_hand(state, 1, 36)  # Only 1 card — must keep it
	var inst_id: int = H.place_on_stage(state, 0, 36)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(36).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[1].size()).is_equal(1)


# --- 022 紫咲シオン: 無軌道雑談（手札シャッフル配り直し）---

func test_022_shion_redistribute() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(22, "シオン", ["KUSOGAKI"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(22, load("res://cards/022_murasaki_shion/card_skills.gd").new())

	var my1: int = H.place_in_hand(state, 0, 22)
	var my2: int = H.place_in_hand(state, 0, 22)
	var opp1: int = H.place_in_hand(state, 1, 22)
	var inst_id: int = H.place_on_stage(state, 0, 22)

	# Phase 0: RANDOM_RESULT 待ち
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(22).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: choice_result でシャッフル順序を決定
	var saved_data: Dictionary = ctx.data.duplicate(true)
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	ctx.data = saved_data
	result = sr.get_skill(22).execute_skill(ctx, 0)

	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# 同枚数配り直し: P0=2枚, P1=1枚
	assert_int(state.hands[0].size()).is_equal(2)
	assert_int(state.hands[1].size()).is_equal(1)

func test_022_shion_both_empty() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(22, "シオン", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(22, load("res://cards/022_murasaki_shion/card_skills.gd").new())
	var inst_id: int = H.place_on_stage(state, 0, 22)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(22).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

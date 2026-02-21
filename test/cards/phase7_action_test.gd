extends GdUnitTestSuite

## Phase 7: Action スキル テスト

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	return (load(path) as GDScript).new()


# --- 016 獅白ぼたん: なんとかしてくれる（自宅2枚→手札、自身帰宅）---

func test_016_botan_home_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(16, "ぼたん", ["ENJOY", "OTAKU"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(16, _load_skill("res://cards/016_shishiro_botan/card_skills.gd"))

	var home1: int = H.place_in_home(state, 16)
	var home2: int = H.place_in_home(state, 16)
	var inst_id: int = H.place_on_stage(state, 0, 16)

	# Phase 0: 自宅から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(16).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 1枚目
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home1, DiffRecorder.new())
	result = sr.get_skill(16).execute_skill(ctx, 0)
	assert_bool(state.hands[0].has(home1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 2枚目 → 自身帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, home2, DiffRecorder.new())
	result = sr.get_skill(16).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(home2)).is_true()
	assert_bool(state.home.has(inst_id)).is_true()


func test_016_botan_not_enough_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(16, "ぼたん", ["ENJOY", "OTAKU"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(16, _load_skill("res://cards/016_shishiro_botan/card_skills.gd"))

	H.place_in_home(state, 16)  # only 1 card
	var inst_id: int = H.place_on_stage(state, 0, 16)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(16).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 023 黒上フブキ: もう帰ろうぜ（自身帰宅→相手場1枚帰宅）---

func test_023_kurokami_self_home_opp_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(23, "黒フブキ", ["TRICKSTER"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(23, _load_skill("res://cards/023_kurokami_fubuki/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 23)
	var inst_id: int = H.place_on_stage(state, 0, 23)

	# Phase 0: 自身帰宅 → 相手場から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(23).execute_skill(ctx, 0)
	assert_bool(state.home.has(inst_id)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 相手カード帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(23).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp_card)).is_true()


# --- 046 クロニー: タイムリープ（自身帰宅→相手場2枚→手札）---

func test_046_kronii_self_home_opp_two_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(46, "クロニー", ["ALCOHOL", "SEXY"], ["INDONESIA"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(46, _load_skill("res://cards/046_ouro_kronii/card_skills.gd"))

	var opp1: int = H.place_on_stage(state, 1, 46)
	var opp2: int = H.place_on_stage(state, 1, 46)
	var inst_id: int = H.place_on_stage(state, 0, 46)

	# Phase 0: 自身帰宅 → 選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(46).execute_skill(ctx, 0)
	assert_bool(state.home.has(inst_id)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 1枚目
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	result = sr.get_skill(46).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 2枚目
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp2, DiffRecorder.new())
	result = sr.get_skill(46).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(opp2)).is_true()


# --- 048 ムメイ: Mumei Berries（手札→デッキ下、1ドロー）---

func test_048_mumei_swap_bottom() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(48, "ムメイ", ["TRICKSTER"], ["INDONESIA"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(48, _load_skill("res://cards/048_nanashi_mumei/card_skills.gd"))

	var hand_card: int = H.place_in_hand(state, 0, 48)
	var deck_card: int = H.place_in_deck_top(state, 48)
	var inst_id: int = H.place_on_stage(state, 0, 48)

	# Phase 0: 手札から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(48).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 手札→デッキ下、ドロー
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	result = sr.get_skill(48).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck.back()).is_equal(hand_card)
	assert_bool(state.hands[0].has(deck_card)).is_true()


# --- 065 火威青: じゃじゃーん！（自身→相手ステージ、1ドロー）---

func test_065_ao_move_to_opp_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(65, "青", ["SEXY"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(65, _load_skill("res://cards/065_hiodoshi_ao/card_skills.gd"))

	var deck_card: int = H.place_in_deck_top(state, 65)
	var inst_id: int = H.place_on_stage(state, 0, 65)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(65).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[1].has(inst_id)).is_true()
	assert_bool(state.stages[0].has(inst_id)).is_false()
	assert_bool(state.hands[0].has(deck_card)).is_true()


func test_065_ao_opp_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(65, "青", ["SEXY"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(65, _load_skill("res://cards/065_hiodoshi_ao/card_skills.gd"))

	H.place_on_stage(state, 1, 65)
	H.place_on_stage(state, 1, 65)
	H.place_on_stage(state, 1, 65)
	var inst_id: int = H.place_on_stage(state, 0, 65)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(65).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# ステージ満杯なので移動しない
	assert_bool(state.stages[0].has(inst_id)).is_true()


# --- 034 赤井はあと: はあちゃまっちゃま～（自宅1枚と入替）---

func test_034_haato_swap_with_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(34, "はあと", ["KUSOGAKI"], ["HOT"], [H.action_skill()]),
		H.make_card_def(99, "HOME_CARD", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(34, _load_skill("res://cards/034_akai_haato/card_skills.gd"))

	var home_card: int = H.place_in_home(state, 99)
	var inst_id: int = H.place_on_stage(state, 0, 34)

	# Phase 0: 自宅から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(34).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 入替
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home_card, DiffRecorder.new())
	result = sr.get_skill(34).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(home_card)).is_true()
	assert_bool(state.home.has(inst_id)).is_true()


# --- 056 ゼータ: 潜入捜査（自身→相手手札、相手手札ランダム→自場）---

func test_056_zeta_infiltration() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(56, "ゼータ", ["TRICKSTER", "ENJOY"], ["STAFF"], [H.action_skill()]),
		H.make_card_def(99, "OPP_CARD", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(56, _load_skill("res://cards/056_vestia_zeta/card_skills.gd"))

	var opp_hand: int = H.place_in_hand(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 56)

	# Phase 0: 自身→相手手札、ランダム選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(56).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(inst_id)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: ランダムで opp_hand を選択 → プレイ先選択
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_hand, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(56).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: ステージにプレイ
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"stolen_card": opp_hand}
	result = sr.get_skill(56).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(opp_hand)).is_true()

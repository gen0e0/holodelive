extends GdUnitTestSuite

## Phase 9: スキル参照 + RNG スキル テスト

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	return (load(path) as GDScript).new()


# --- 008 博衣こより: それこよの！（相手場カードのplay skill使用）---

func test_008_koyori_use_opp_play_skill() -> void:
	# 009 ロボ子(1ドロー) を相手場に配置し、こよりがそのスキルを使う
	var env: Dictionary = H.create_test_env([
		H.make_card_def(8, "こより", ["INTEL"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(9, "ロボ子", [], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(8, _load_skill("res://cards/008_hakui_koyori/card_skills.gd"))
	sr.register(9, _load_skill("res://cards/009_roboco/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 9)
	var inst_id: int = H.place_on_stage(state, 0, 8)
	H.place_in_deck_top(state, 9)  # ドロー用

	# Phase 0: 相手場から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(8).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: ロボ子を選択 → そのplay skill(1ドロー)が即時実行
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new(), sr)
	ctx.data = {}
	result = sr.get_skill(8).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# こよりのプレイヤー(0)が1ドロー
	assert_int(state.hands[0].size()).is_equal(1)


func test_008_koyori_no_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(8, "こより", ["INTEL"], ["LOVELY"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(8, _load_skill("res://cards/008_hakui_koyori/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 8)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(8).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 044 小鳥遊キアラ: HOLOTALK（自宅カードのplay skill使用）---

func test_044_kiara_use_home_play_skill() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(44, "キアラ", ["REACTION"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(9, "ロボ子", [], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(44, _load_skill("res://cards/044_takanashi_kiara/card_skills.gd"))
	sr.register(9, _load_skill("res://cards/009_roboco/card_skills.gd"))

	var home_card: int = H.place_in_home(state, 9)
	var inst_id: int = H.place_on_stage(state, 0, 44)
	H.place_in_deck_top(state, 9)

	# Phase 0: 自宅から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(44).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: ロボ子を選択 → 1ドロー
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home_card, DiffRecorder.new(), sr)
	ctx.data = {}
	result = sr.get_skill(44).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)


# --- 066 音乃瀬奏: 尻を揉むために（前のカードのplay skill使用）---

func test_066_kanade_use_prev_skill() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(66, "奏", ["KUSOGAKI"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(9, "ロボ子", [], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(66, _load_skill("res://cards/066_otonose_kanade/card_skills.gd"))
	sr.register(9, _load_skill("res://cards/009_roboco/card_skills.gd"))

	var prev_card: int = H.place_on_stage(state, 0, 9)  # 1st
	var inst_id: int = H.place_on_stage(state, 0, 66)   # 2nd
	H.place_in_deck_top(state, 9)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(66).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.hands[0].size()).is_equal(1)


func test_066_kanade_first_position_no_prev() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(66, "奏", ["KUSOGAKI"], ["LOVELY"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(66, _load_skill("res://cards/066_otonose_kanade/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 66)  # 1st = no prev

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(66).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 020 猫又おかゆ: 全ホロメン妹化計画（ダイス勝負）---

func test_020_okayu_win() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(20, "おかゆ", ["SEXY", "VOCAL"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(20, _load_skill("res://cards/020_nekomata_okayu/card_skills.gd"))

	var opp_first: int = H.place_on_stage(state, 1, 20)
	var inst_id: int = H.place_on_stage(state, 0, 20)

	# Phase 0: 自分のダイス → 5
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 相手のダイス → 3 (5 >= 3 → 勝ち)
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 5, DiffRecorder.new())
	ctx.data = {"my_roll": 5}
	result = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 判定
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 3, DiffRecorder.new())
	ctx.data = {"my_roll": 5}
	result = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(opp_first)).is_true()


func test_020_okayu_lose() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(20, "おかゆ", ["SEXY", "VOCAL"], ["COOL"], [H.action_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(20, _load_skill("res://cards/020_nekomata_okayu/card_skills.gd"))

	H.place_on_stage(state, 1, 20)
	var inst_id: int = H.place_on_stage(state, 0, 20)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(20).execute_skill(ctx, 0)

	# 自分2, 相手5 → 負け → 帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 2, DiffRecorder.new())
	ctx.data = {"my_roll": 2}
	sr.get_skill(20).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 5, DiffRecorder.new())
	ctx.data = {"my_roll": 2}
	var result: SkillResult = sr.get_skill(20).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(inst_id)).is_true()


# --- 041 一伊那尓栖: ネクロノミコン play（ダイス効果分岐）---

func test_041_ina_dice_roll_1_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill("res://cards/041_ninomae_inanis/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 1)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 1, DiffRecorder.new())
	ctx.data = {}
	var result: SkillResult = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(inst_id)).is_true()


func test_041_ina_dice_roll_2_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill("res://cards/041_ninomae_inanis/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 1)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 2, DiffRecorder.new())
	ctx.data = {}
	var result: SkillResult = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(inst_id)).is_true()


func test_041_ina_dice_roll_6_choose_opp() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "OPP", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill("res://cards/041_ninomae_inanis/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 1)

	# ダイス6 → 選択
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 6, DiffRecorder.new())
	ctx.data = {}
	var result: SkillResult = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# 相手カード選択 → 帰宅
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp_card, DiffRecorder.new())
	ctx.data = {"roll": 6}
	result = sr.get_skill(41).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp_card)).is_true()


# --- 059 ぺこらマミー: ごはんよー（じゃんけん3回→帰宅→自身除去）---

func test_059_mummy_three_wins() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(59, "マミー", [], [], [H.passive_skill()]),
		H.make_card_def(99, "OPP", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(59, _load_skill("res://cards/059_pekora_mummy/card_skills.gd"))

	var opp1: int = H.place_on_stage(state, 1, 99)
	var opp2: int = H.place_on_stage(state, 1, 99)
	var opp3: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 59)

	# Phase 0: じゃんけん1 → 勝ち
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(59).execute_skill(ctx, 0)

	# Phase 1: 勝ち
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 1, DiffRecorder.new())
	ctx.data = {"wins": 1}
	sr.get_skill(59).execute_skill(ctx, 0)

	# Phase 2: 勝ち
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 1, DiffRecorder.new())
	ctx.data = {"wins": 2}
	sr.get_skill(59).execute_skill(ctx, 0)

	# Phase 3: 勝ち → 3勝 → 相手3枚帰宅、自身除去
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 3, 1, DiffRecorder.new())
	ctx.data = {"wins": 3}
	var result: SkillResult = sr.get_skill(59).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# 3勝+1 = 4勝分... いや wins は最後に +1 される
	# Phase 3: wins = ctx.data["wins"](=3) + choice_result(=1) = 4 wins... しかしstageは3枚しかない
	# 実際: 3枚帰宅
	assert_bool(state.home.has(opp1)).is_true()
	assert_bool(state.home.has(opp2)).is_true()
	assert_bool(state.home.has(opp3)).is_true()
	assert_bool(state.removed.has(inst_id)).is_true()


func test_059_mummy_no_wins() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(59, "マミー", [], [], [H.passive_skill()]),
		H.make_card_def(99, "OPP", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(59, _load_skill("res://cards/059_pekora_mummy/card_skills.gd"))

	var opp1: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 59)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, 0, DiffRecorder.new())
	ctx.data = {"wins": 0}
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, 0, DiffRecorder.new())
	ctx.data = {"wins": 0}
	sr.get_skill(59).execute_skill(ctx, 0)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 3, 0, DiffRecorder.new())
	ctx.data = {"wins": 0}
	var result: SkillResult = sr.get_skill(59).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# 0勝 → 帰宅なし
	assert_bool(state.stages[1].has(opp1)).is_true()
	# 自身は除去
	assert_bool(state.removed.has(inst_id)).is_true()


# --- 034 赤井はあと: はあちゃまっちゃま～（自宅カードと入替→play skill発動）---

func test_034_haato_swap_and_trigger_play_skill() -> void:
	# 009 ロボ子(1ドロー) を自宅に置き、はあとと入替→ロボ子のplay skillが発動
	var env: Dictionary = H.create_test_env([
		H.make_card_def(34, "はあと", ["KUSOGAKI"], ["HOT"], [H.action_skill()]),
		H.make_card_def(9, "ロボ子", [], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(34, _load_skill("res://cards/034_akai_haato/card_skills.gd"))
	sr.register(9, _load_skill("res://cards/009_roboco/card_skills.gd"))

	var home_card: int = H.place_in_home(state, 9)
	var inst_id: int = H.place_on_stage(state, 0, 34)
	H.place_in_deck_top(state, 9)  # ドロー用

	# Phase 0: 自宅から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new(), sr)
	var result: SkillResult = sr.get_skill(34).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: ロボ子を選択 → 入替 + play skill(1ドロー)発動
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home_card, DiffRecorder.new(), sr)
	ctx.data = {}
	result = sr.get_skill(34).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# はあと→自宅、ロボ子→ステージ
	assert_bool(state.stages[0].has(home_card)).is_true()
	assert_bool(state.home.has(inst_id)).is_true()
	# ロボ子のplay skill(1ドロー)が発動
	assert_int(state.hands[0].size()).is_equal(1)

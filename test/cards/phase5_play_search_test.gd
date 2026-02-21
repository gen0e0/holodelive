extends GdUnitTestSuite

## Phase 5: 手札プレイ + デッキサーチ スキル テスト

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	return (load(path) as GDScript).new()


# --- 003 白上フブキ: フブキングダム（手札JP♥/◆→プレイ）---

func test_003_fubuki_play_to_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(3, "フブキ", ["OTAKU", "CHARISMA"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(99, "JP_COOL", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(3, _load_skill("res://cards/003_shirakami_fubuki/card_skills.gd"))

	var hand_card: int = H.place_in_hand(state, 0, 99)  # COOL suit = JP◆
	var inst_id: int = H.place_on_stage(state, 0, 3)

	# Phase 0: 手札から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(3).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: カード選択 → ゾーン選択
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(3).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: ステージにプレイ
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(3).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hand_card)).is_true()


func test_003_fubuki_play_to_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(3, "フブキ", ["OTAKU", "CHARISMA"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(99, "JP_LOVELY", [], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(3, _load_skill("res://cards/003_shirakami_fubuki/card_skills.gd"))

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 3)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(3).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(3).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "backstage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(3).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.backstages[0]).is_equal(hand_card)


func test_003_fubuki_no_matching_suit() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(3, "フブキ", ["OTAKU", "CHARISMA"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(99, "EN_CARD", [], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(3, _load_skill("res://cards/003_shirakami_fubuki/card_skills.gd"))

	H.place_in_hand(state, 0, 99)  # ENGLISH → not JP
	var inst_id: int = H.place_on_stage(state, 0, 3)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(3).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 040 がうる・ぐら: a（手札EN★→ステージ）---

func test_040_gura_play_en() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(40, "ぐら", ["CHARISMA"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(99, "EN_CARD", [], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(40, _load_skill("res://cards/040_gawr_gura/card_skills.gd"))

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 40)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(40).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	result = sr.get_skill(40).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hand_card)).is_true()


func test_040_gura_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(40, "ぐら", ["CHARISMA"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(99, "EN_CARD", [], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(40, _load_skill("res://cards/040_gawr_gura/card_skills.gd"))

	H.place_in_hand(state, 0, 99)
	H.place_on_stage(state, 0, 40)
	H.place_on_stage(state, 0, 40)
	var inst_id: int = H.place_on_stage(state, 0, 40)  # 3枚目 = 満杯

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(40).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 053 アーニャ: スーパー通訳（手札JP☀/ID☽→プレイ）---

func test_053_anya_play_hot() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(53, "アーニャ", ["DUELIST"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(99, "HOT_CARD", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(53, _load_skill("res://cards/053_anya_melfissa/card_skills.gd"))

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 53)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hand_card)).is_true()


func test_053_anya_play_indonesia() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(53, "アーニャ", ["DUELIST"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(99, "ID_CARD", [], ["INDONESIA"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(53, _load_skill("res://cards/053_anya_melfissa/card_skills.gd"))

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 53)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "backstage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(53).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.backstages[0]).is_equal(hand_card)


# --- 012 AZKi: Guess!（手札SEISO→プレイ）---

func test_012_azki_guess_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(12, "AZKi", ["SEISO"], ["COOL"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "SEISO_CARD", ["SEISO"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(12, _load_skill("res://cards/012_azki/card_skills.gd"))

	var hand_card: int = H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 12)

	# skill_index=1 (Guess!)
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hand_card, DiffRecorder.new())
	ctx.data = {}
	result = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, "stage", DiffRecorder.new())
	ctx.data = {"chosen_card": hand_card}
	result = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hand_card)).is_true()


func test_012_azki_guess_no_seiso() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(12, "AZKi", ["SEISO"], ["COOL"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "NOT_SEISO", ["OTAKU"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(12, _load_skill("res://cards/012_azki/card_skills.gd"))

	H.place_in_hand(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 12)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(12).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 014 ラプラス: かつもーく（デッキサーチholoX）---

func test_014_laplus_find_holox() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(14, "ラプラス", ["OTAKU", "KUSOGAKI"], ["COOL"], [H.play_skill()]),
		H.make_card_def(31, "ルイ", ["CHARISMA"], ["COOL"], []),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(14, _load_skill("res://cards/014_laplus_darkness/card_skills.gd"))

	var other1: int = H.place_in_deck_top(state, 99)
	var lui: int = H.place_in_deck_top(state, 31)  # ← deck[1] にルイが
	# deck = [lui 関連のカードを先に配置... 逆順で]
	# 実際: place_in_deck_top は push_front なので最後に追加したのが先頭
	# deck = [lui_id(card_id=31), other1(card_id=99)]
	# 先頭のルイが見つかるはず... いや、順番を再確認
	# place_in_deck_top(state, 99) → deck = [other1]
	# place_in_deck_top(state, 31) → deck = [lui, other1]
	# デッキ上からめくるので lui が最初に見つかる

	var inst_id: int = H.place_on_stage(state, 0, 14)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(14).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(lui)).is_true()


func test_014_laplus_not_found_all_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(14, "ラプラス", ["OTAKU", "KUSOGAKI"], ["COOL"], [H.play_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(14, _load_skill("res://cards/014_laplus_darkness/card_skills.gd"))

	var c1: int = H.place_in_deck_top(state, 99)
	var c2: int = H.place_in_deck_top(state, 99)
	var inst_id: int = H.place_on_stage(state, 0, 14)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(14).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# holoXが見つからないので全て帰宅
	assert_bool(state.home.has(c1)).is_true()
	assert_bool(state.home.has(c2)).is_true()
	assert_int(state.deck.size()).is_equal(0)


func test_014_laplus_skip_non_holox_before_hit() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(14, "ラプラス", ["OTAKU", "KUSOGAKI"], ["COOL"], [H.play_skill()]),
		H.make_card_def(7, "いろは", ["REACTION"], ["COOL"], []),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(14, _load_skill("res://cards/014_laplus_darkness/card_skills.gd"))

	var iroha: int = H.place_in_deck_top(state, 7)
	var other: int = H.place_in_deck_top(state, 99)
	# deck = [other, iroha]
	var inst_id: int = H.place_on_stage(state, 0, 14)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(14).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# other は帰宅、iroha はステージ
	assert_bool(state.home.has(other)).is_true()
	assert_bool(state.stages[0].has(iroha)).is_true()


# --- 067 一条莉々華: 酒持ってこーい（デッキ上4枚→ALCOHOL→プレイ）---

func test_067_ririka_find_alcohol() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(67, "莉々華", ["TRICKSTER", "ALCOHOL"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "NO_ALCOHOL", ["OTAKU"], ["HOT"], []),
		H.make_card_def(98, "HAS_ALCOHOL", ["ALCOHOL"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(67, _load_skill("res://cards/067_ichijou_ririka/card_skills.gd"))

	var alcohol_card: int = H.place_in_deck_top(state, 98)
	var no1: int = H.place_in_deck_top(state, 99)
	var no2: int = H.place_in_deck_top(state, 99)
	# deck = [no2, no1, alcohol_card]
	var inst_id: int = H.place_on_stage(state, 0, 67)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(67).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	# no2, no1 は帰宅済み
	assert_bool(state.home.has(no2)).is_true()
	assert_bool(state.home.has(no1)).is_true()

	# Phase 1: ステージにプレイ
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, "stage", DiffRecorder.new())
	ctx.data = {"found_card": alcohol_card}
	result = sr.get_skill(67).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(alcohol_card)).is_true()


func test_067_ririka_no_alcohol() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(67, "莉々華", ["TRICKSTER", "ALCOHOL"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "NO_ALCOHOL", ["OTAKU"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(67, _load_skill("res://cards/067_ichijou_ririka/card_skills.gd"))

	var c1: int = H.place_in_deck_top(state, 99)
	var c2: int = H.place_in_deck_top(state, 99)
	var c3: int = H.place_in_deck_top(state, 99)
	var inst_id: int = H.place_on_stage(state, 0, 67)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(67).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# 全て帰宅
	assert_bool(state.home.has(c1)).is_true()
	assert_bool(state.home.has(c2)).is_true()
	assert_bool(state.home.has(c3)).is_true()


# --- 063 フワワ: 番犬（モココ=64を検索→ステージ）---

func test_063_fuwawa_find_mococo_in_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill("res://cards/063_fuwawa_abyssgard/card_skills.gd"))

	var mococo: int = H.place_in_deck_top(state, 64)
	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(mococo)).is_true()


func test_063_fuwawa_find_mococo_in_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill("res://cards/063_fuwawa_abyssgard/card_skills.gd"))

	var mococo: int = H.place_in_home(state, 64)
	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(mococo)).is_true()


func test_063_fuwawa_find_mococo_in_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill("res://cards/063_fuwawa_abyssgard/card_skills.gd"))

	var mococo: int = H.place_in_hand(state, 0, 64)
	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(mococo)).is_true()
	assert_bool(state.hands[0].has(mococo)).is_false()


func test_063_fuwawa_not_found() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill("res://cards/063_fuwawa_abyssgard/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 63)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


func test_063_fuwawa_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(63, _load_skill("res://cards/063_fuwawa_abyssgard/card_skills.gd"))

	H.place_in_deck_top(state, 64)
	H.place_on_stage(state, 0, 63)
	H.place_on_stage(state, 0, 63)
	var inst_id: int = H.place_on_stage(state, 0, 63)  # 3枠満杯

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(63).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# ステージ満杯なのでモココはデッキに残る
	assert_int(state.deck.size()).is_equal(1)


# --- 064 モココ: 忠犬（フワワ=63を検索→ステージ）---

func test_064_mococo_find_fuwawa_in_deck() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(63, "フワワ", ["ENJOY", "KUSOGAKI"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(64, _load_skill("res://cards/064_mococo_abyssgard/card_skills.gd"))

	var fuwawa: int = H.place_in_deck_top(state, 63)
	var inst_id: int = H.place_on_stage(state, 0, 64)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(64).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(fuwawa)).is_true()


func test_064_mococo_not_found() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(64, "モココ", ["REACTION", "DUELIST"], ["ENGLISH"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(64, _load_skill("res://cards/064_mococo_abyssgard/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 64)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(64).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

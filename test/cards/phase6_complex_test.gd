extends GdUnitTestSuite

## Phase 6: 複雑な効果 Play スキル テスト

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	return (load(path) as GDScript).new()


# --- 062 古石ビジュー: 産んじゃう…！（対面1st→こちらステージ）---

func test_062_bijou_steal_opp_first() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(62, "ビジュー", ["KUSOGAKI", "TRICKSTER"], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(62, _load_skill("res://cards/062_koseki_bijou/card_skills.gd"))

	var opp_first: int = H.place_on_stage(state, 1, 62)
	var inst_id: int = H.place_on_stage(state, 0, 62)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(62).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(opp_first)).is_true()
	assert_bool(state.stages[1].has(opp_first)).is_false()


func test_062_bijou_no_opp_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(62, "ビジュー", ["KUSOGAKI", "TRICKSTER"], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(62, _load_skill("res://cards/062_koseki_bijou/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 62)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(62).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 069 轟はじめ: タイマンだじぇ（両1st→帰宅）---

func test_069_hajime_both_first_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(69, "はじめ", ["DUELIST"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(69, _load_skill("res://cards/069_todoroki_hajime/card_skills.gd"))

	var my_first: int = H.place_on_stage(state, 0, 69)
	var opp_first: int = H.place_on_stage(state, 1, 69)
	var inst_id: int = H.place_on_stage(state, 0, 69)
	# stages[0] = [my_first, inst_id], stages[1] = [opp_first]
	# inst_id が発動 → my_first(1st) と opp_first(1st) が帰宅

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(69).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(my_first)).is_true()
	assert_bool(state.home.has(opp_first)).is_true()
	assert_bool(state.stages[0].has(inst_id)).is_true()


# --- 047 ハコス・ベールズ: カオスそのもの（位置入替）---

func test_047_baelz_swap_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(47, "ベールズ", ["KUSOGAKI"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(47, _load_skill("res://cards/047_hakos_baelz/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 47)
	var inst_id: int = H.place_on_stage(state, 0, 47)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(47).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(47).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# inst_id は相手ステージ、opp_card は自分ステージ
	assert_bool(state.stages[1].has(inst_id)).is_true()
	assert_bool(state.stages[0].has(opp_card)).is_true()


func test_047_baelz_no_target() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(47, "ベールズ", ["KUSOGAKI"], ["INDONESIA"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(47, _load_skill("res://cards/047_hakos_baelz/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 47)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(47).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 032 癒月ちょこ: 身体測定（相手楽屋オープン）---

func test_032_choco_open_opp_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(32, "ちょこ", ["SEXY", "ALCOHOL"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(32, _load_skill("res://cards/032_yuzuki_choco/card_skills.gd"))

	var opp_bs: int = H.place_on_backstage(state, 1, 32)
	var inst_id: int = H.place_on_stage(state, 0, 32)

	assert_bool(state.instances[opp_bs].face_down).is_true()

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(32).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.instances[opp_bs].face_down).is_false()


func test_032_choco_no_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(32, "ちょこ", ["SEXY", "ALCOHOL"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(32, _load_skill("res://cards/032_yuzuki_choco/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 32)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(32).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 033 アキ: あらあらぁ（自分楽屋オープン）---

func test_033_aki_open_own_backstage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(33, "アキ", ["ALCOHOL", "DUELIST"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(33, _load_skill("res://cards/033_aki_rosenthal/card_skills.gd"))

	var my_bs: int = H.place_on_backstage(state, 0, 33)
	var inst_id: int = H.place_on_stage(state, 0, 33)

	assert_bool(state.instances[my_bs].face_down).is_true()

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(33).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.instances[my_bs].face_down).is_false()


# --- 051 ムーナ: 何見てンだヨ（特定12キャラ帰宅）---

func test_051_moona_remove_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(51, "ムーナ", ["VOCAL"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(15, "すいせい", [], [], []),
		H.make_card_def(99, "OTHER", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(51, _load_skill("res://cards/051_moona_hoshinova/card_skills.gd"))

	var suisei: int = H.place_on_stage(state, 1, 15)
	var other: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 51)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(51).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(suisei)).is_true()
	assert_bool(state.stages[1].has(other)).is_true()


func test_051_moona_no_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(51, "ムーナ", ["VOCAL"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(99, "OTHER", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(51, _load_skill("res://cards/051_moona_hoshinova/card_skills.gd"))

	H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 51)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(51).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.home.size()).is_equal(0)


# --- 024 夏色まつり: まつりライン（SEISO全帰宅→WILD付与）---

func test_024_matsuri_seiso_home_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(24, "まつり", ["SEISO"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "SEISO_CARD", ["SEISO"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(24, _load_skill("res://cards/024_natsuiro_matsuri/card_skills.gd"))

	var seiso_card: int = H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 24)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(24).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(seiso_card)).is_true()
	# WILD modifier 付与確認
	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("WILD")


func test_024_matsuri_no_seiso_no_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(24, "まつり", ["SEISO"], ["HOT"], [H.play_skill()]),
		H.make_card_def(99, "NOT_SEISO", ["OTAKU"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(24, _load_skill("res://cards/024_natsuiro_matsuri/card_skills.gd"))

	H.place_on_stage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 24)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(24).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.instances[inst_id].modifiers.size()).is_equal(0)


func test_024_matsuri_self_not_removed() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(24, "まつり", ["SEISO"], ["HOT"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(24, _load_skill("res://cards/024_natsuiro_matsuri/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 24)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(24).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(inst_id)).is_true()


# --- 057 こぼ: クソガキング（KUSOGAKI数分、相手場→手札）---

func test_057_kobo_return_by_kusogaki_count() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(57, "こぼ", ["KUSOGAKI", "CHARISMA"], ["STAFF"], [H.play_skill()]),
		H.make_card_def(99, "KUSO", ["KUSOGAKI"], ["HOT"], []),
		H.make_card_def(98, "OPP", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(57, _load_skill("res://cards/057_kobo_kanaeru/card_skills.gd"))

	var opp1: int = H.place_on_stage(state, 1, 98)
	var opp2: int = H.place_on_stage(state, 1, 98)
	# 自分場: こぼ(KUSOGAKI) + もう1枚KUSOGAKI = 2枚
	var kuso_card: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 57)

	# Phase 0: KUSOGAKI 2枚 → 2回選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# 1枚目選択
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp1, DiffRecorder.new())
	ctx.data = {"remaining": 2}
	result = sr.get_skill(57).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# 2枚目選択
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, opp2, DiffRecorder.new())
	ctx.data = {"remaining": 1}
	result = sr.get_skill(57).execute_skill(ctx, 0)
	assert_bool(state.hands[1].has(opp2)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


func test_057_kobo_no_kusogaki() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(57, "こぼ_no_kuso", [], ["STAFF"], [H.play_skill()]),
		H.make_card_def(98, "OPP", [], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(57, _load_skill("res://cards/057_kobo_kanaeru/card_skills.gd"))

	H.place_on_stage(state, 1, 98)
	# card_id=57 のカードだが、icons に KUSOGAKI がない
	var inst_id: int = H.place_on_stage(state, 0, 57)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(57).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 058 桐生ココ: 伝説のドラゴン（全帰宅→自身除去）---

func test_058_coco_all_home_self_removed() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(58, "ココ", [], [], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], [], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(58, _load_skill("res://cards/058_kiryu_coco/card_skills.gd"))

	var my_other: int = H.place_on_stage(state, 0, 99)
	var opp_card: int = H.place_on_stage(state, 1, 99)
	var opp_bs: int = H.place_on_backstage(state, 1, 99)
	var inst_id: int = H.place_on_stage(state, 0, 58)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(58).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	# 全て帰宅
	assert_bool(state.home.has(my_other)).is_true()
	assert_bool(state.home.has(opp_card)).is_true()
	assert_bool(state.home.has(opp_bs)).is_true()
	# 自身は除去
	assert_bool(state.removed.has(inst_id)).is_true()
	assert_bool(state.stages[0].has(inst_id)).is_false()

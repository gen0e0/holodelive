extends GdUnitTestSuite

## Phase 2: 単一選択 Play スキル テスト

var H := SkillTestHelper


func _load_skill(card_id: int, path: String) -> BaseCardSkill:
	var script: GDScript = load(path)
	return script.new()


# --- 006 天音かなた: ぎゅむっ（相手場→デッキ先頭）---

func test_006_kanata_to_deck_top() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(6, "かなた", ["REACTION"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(6, _load_skill(6, "res://cards/006_amane_kanata/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 6)
	var inst_id: int = H.place_on_stage(state, 0, 6)

	# Phase 0
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(6).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(opp_card)).is_true()

	# Phase 1
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(6).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[1].has(opp_card)).is_false()
	assert_int(state.deck[0]).is_equal(opp_card)

func test_006_kanata_no_targets() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(6, "かなた", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(6, _load_skill(6, "res://cards/006_amane_kanata/card_skills.gd"))
	var inst_id: int = H.place_on_stage(state, 0, 6)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(6).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 037 えーちゃん: 休むのも仕事です！（相手場→帰宅）---

func test_037_a_chan_to_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(37, "えーちゃん", [], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(37, _load_skill(37, "res://cards/037_a_chan/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 37)
	var inst_id: int = H.place_on_stage(state, 0, 37)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(37).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(37).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(opp_card)).is_true()


# --- 042 森カリオペ: メメント・モリ（相手場→デッキ最下部）---

func test_042_calliope_to_deck_bottom() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(42, "カリオペ", ["VOCAL"], ["ENGLISH"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(42, _load_skill(42, "res://cards/042_mori_calliope/card_skills.gd"))

	var opp_card: int = H.place_on_stage(state, 1, 42)
	var inst_id: int = H.place_on_stage(state, 0, 42)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(42).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, opp_card, DiffRecorder.new())
	result = sr.get_skill(42).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_int(state.deck.back()).is_equal(opp_card)


# --- 011 桃鈴ねね: 見て見て！ギラファ！（自場自身除外→手札）---

func test_011_nene_return_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(11, "ねね", ["KUSOGAKI"], ["LOVELY"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(11, _load_skill(11, "res://cards/011_momosuzu_nene/card_skills.gd"))

	var other_card: int = H.place_on_stage(state, 0, 11)
	var inst_id: int = H.place_on_stage(state, 0, 11)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(11).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(other_card)).is_true()
	assert_bool(result.valid_targets.has(inst_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, other_card, DiffRecorder.new())
	result = sr.get_skill(11).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(other_card)).is_true()

func test_011_nene_no_other_cards() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(11, "ねね", [], [], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(11, _load_skill(11, "res://cards/011_momosuzu_nene/card_skills.gd"))
	var inst_id: int = H.place_on_stage(state, 0, 11)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(11).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 029 大空スバル: 大空警察（相手場SEXY/KUSOGAKI/TRICKSTER→帰宅）---

func test_029_subaru_police() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(29, "スバル", ["REACTION"], ["HOT"], [H.play_skill()]),
		H.make_card_def(90, "SEXY_card", ["SEXY"], ["HOT"], []),
		H.make_card_def(91, "SEISO_card", ["SEISO"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(29, _load_skill(29, "res://cards/029_oozora_subaru/card_skills.gd"))

	var sexy_id: int = H.place_on_stage(state, 1, 90)
	var seiso_id: int = H.place_on_stage(state, 1, 91)
	var inst_id: int = H.place_on_stage(state, 0, 29)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(29).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(sexy_id)).is_true()
	assert_bool(result.valid_targets.has(seiso_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, sexy_id, DiffRecorder.new())
	result = sr.get_skill(29).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(sexy_id)).is_true()


# --- 054 カエラ: メンテナンス（相手場DUELIST→帰宅）---

func test_054_kaela_duelist() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(54, "カエラ", ["INTEL"], ["INDONESIA"], [H.play_skill()]),
		H.make_card_def(92, "DUELIST_card", ["DUELIST"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(54, _load_skill(54, "res://cards/054_kaela_kovalskia/card_skills.gd"))

	var duelist_id: int = H.place_on_stage(state, 1, 92)
	var inst_id: int = H.place_on_stage(state, 0, 54)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(54).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, duelist_id, DiffRecorder.new())
	result = sr.get_skill(54).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(duelist_id)).is_true()


# --- 061 ネリッサ: BAN PANTSU（相手場SEXY→帰宅）---

func test_061_nerissa_sexy() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(61, "ネリッサ", ["VOCAL", "SEXY"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(93, "SEXY_card", ["SEXY"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(61, _load_skill(61, "res://cards/061_nerissa_ravencroft/card_skills.gd"))

	var sexy_id: int = H.place_on_stage(state, 1, 93)
	var inst_id: int = H.place_on_stage(state, 0, 61)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(61).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, sexy_id, DiffRecorder.new())
	result = sr.get_skill(61).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.home.has(sexy_id)).is_true()


# --- 045 セレス・ファウナ: 癒しの極地（相手場KUSOGAKI→自分ステージ）---

func test_045_fauna_steal_kusogaki() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(45, "ファウナ", ["INTEL", "SEISO"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(94, "KG_card", ["KUSOGAKI"], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(45, _load_skill(45, "res://cards/045_ceres_fauna/card_skills.gd"))

	var kg_id: int = H.place_on_stage(state, 1, 94)
	var inst_id: int = H.place_on_stage(state, 0, 45)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(45).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, kg_id, DiffRecorder.new())
	result = sr.get_skill(45).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(kg_id)).is_true()
	assert_bool(state.stages[1].has(kg_id)).is_false()

func test_045_fauna_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(45, "ファウナ", ["INTEL"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(94, "KG_card", ["KUSOGAKI"], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(45, _load_skill(45, "res://cards/045_ceres_fauna/card_skills.gd"))

	H.place_on_stage(state, 1, 94)
	H.place_on_stage(state, 0, 45)
	H.place_on_stage(state, 0, 45)
	var inst_id: int = H.place_on_stage(state, 0, 45)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(45).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

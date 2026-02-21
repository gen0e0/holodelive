extends GdUnitTestSuite

## Phase 3: 自宅/デッキ操作 Play スキル テスト

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	var script: GDScript = load(path)
	return script.new()


# --- 007 風真いろは: うーばーござる（自宅JP→手札）---

func test_007_iroha_home_jp_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(7, "いろは", ["DUELIST"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(90, "JP_card", ["SEISO"], ["LOVELY"], []),
		H.make_card_def(91, "EN_card", ["SEISO"], ["ENGLISH"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(7, _load_skill("res://cards/007_kazama_iroha/card_skills.gd"))

	var jp_id: int = H.place_in_home(state, 90)
	var en_id: int = H.place_in_home(state, 91)
	var inst_id: int = H.place_on_stage(state, 0, 7)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(7).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(jp_id)).is_true()
	assert_bool(result.valid_targets.has(en_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, jp_id, DiffRecorder.new())
	result = sr.get_skill(7).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(jp_id)).is_true()


# --- 002 湊あくあ: あてぃしのこと好きすぎぃ！（自宅JP→ステージ）---

func test_002_aqua_home_jp_to_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(2, "あくあ", ["CHARISMA"], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(90, "HOT_card", ["ENJOY"], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(2, _load_skill("res://cards/002_minato_aqua/card_skills.gd"))

	var hot_id: int = H.place_in_home(state, 90)
	var inst_id: int = H.place_on_stage(state, 0, 2)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(2).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, hot_id, DiffRecorder.new())
	result = sr.get_skill(2).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(hot_id)).is_true()
	assert_bool(state.home.has(hot_id)).is_false()

func test_002_aqua_stage_full() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(2, "あくあ", [], ["LOVELY"], [H.play_skill()]),
		H.make_card_def(90, "card", [], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(2, _load_skill("res://cards/002_minato_aqua/card_skills.gd"))
	H.place_in_home(state, 90)
	H.place_on_stage(state, 0, 2)
	H.place_on_stage(state, 0, 2)
	var inst_id: int = H.place_on_stage(state, 0, 2)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(2).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 031 鷹嶺ルイ: 有能女幹部（自宅EN/ID→手札）---

func test_031_lui_en_id_to_hand() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(31, "ルイ", ["INTEL"], ["HOT"], [H.play_skill()]),
		H.make_card_def(90, "EN_card", ["VOCAL"], ["ENGLISH"], []),
		H.make_card_def(91, "JP_card", ["VOCAL"], ["LOVELY"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(31, _load_skill("res://cards/031_takane_lui/card_skills.gd"))

	var en_id: int = H.place_in_home(state, 90)
	var jp_id: int = H.place_in_home(state, 91)
	var inst_id: int = H.place_on_stage(state, 0, 31)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(31).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(en_id)).is_true()
	assert_bool(result.valid_targets.has(jp_id)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, en_id, DiffRecorder.new())
	result = sr.get_skill(31).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(en_id)).is_true()


# --- 038 春先のどか: 大丈夫ですか？？（自宅→ステージ）---

func test_038_nodoka_home_to_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(38, "のどか", [], ["ENGLISH"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(38, _load_skill("res://cards/038_harusaki_nodoka/card_skills.gd"))

	var home_id: int = H.place_in_home(state, 38)
	var inst_id: int = H.place_on_stage(state, 0, 38)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(38).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, home_id, DiffRecorder.new())
	result = sr.get_skill(38).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.stages[0].has(home_id)).is_true()

func test_038_nodoka_home_empty() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(38, "のどか", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(38, _load_skill("res://cards/038_harusaki_nodoka/card_skills.gd"))
	var inst_id: int = H.place_on_stage(state, 0, 38)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(38).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)


# --- 060 シオリ: 知識の収集家（場/自宅のINTEL→手札）---

func test_060_shiori_intel_from_home() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(60, "シオリ", ["INTEL"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(90, "INTEL_card", ["INTEL"], ["COOL"], []),
		H.make_card_def(91, "OTHER_card", ["VOCAL"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(60, _load_skill("res://cards/060_shiori_novella/card_skills.gd"))

	var intel_home: int = H.place_in_home(state, 90)
	var other_home: int = H.place_in_home(state, 91)
	var inst_id: int = H.place_on_stage(state, 0, 60)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(60).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(intel_home)).is_true()
	assert_bool(result.valid_targets.has(other_home)).is_false()

	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, intel_home, DiffRecorder.new())
	result = sr.get_skill(60).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[0].has(intel_home)).is_true()

func test_060_shiori_intel_from_opp_stage() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(60, "シオリ", ["INTEL"], ["ENGLISH"], [H.play_skill()]),
		H.make_card_def(90, "INTEL_card", ["INTEL"], ["COOL"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(60, _load_skill("res://cards/060_shiori_novella/card_skills.gd"))

	var opp_intel: int = H.place_on_stage(state, 1, 90)
	var inst_id: int = H.place_on_stage(state, 0, 60)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(60).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)
	assert_bool(result.valid_targets.has(opp_intel)).is_true()


# --- 019 不知火フレア: 俺のイナ！（自宅→自分手札、自宅→相手手札）---

func test_019_flare_both_pick() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(19, "フレア", ["INTEL"], ["COOL"], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(19, _load_skill("res://cards/019_shiranui_flare/card_skills.gd"))

	var h1: int = H.place_in_home(state, 19)
	var h2: int = H.place_in_home(state, 19)
	var inst_id: int = H.place_on_stage(state, 0, 19)

	# Phase 0: 自分が自宅から選択
	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(19).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 1: 自分のカードを手札に → 相手の選択へ
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 1, h1, DiffRecorder.new())
	result = sr.get_skill(19).execute_skill(ctx, 0)
	assert_bool(state.hands[0].has(h1)).is_true()
	assert_int(result.status).is_equal(SkillResult.Status.WAITING_FOR_CHOICE)

	# Phase 2: 相手がカードを手札に
	ctx = SkillContext.new(state, env.registry, inst_id, 0, 2, h2, DiffRecorder.new())
	result = sr.get_skill(19).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_bool(state.hands[1].has(h2)).is_true()

func test_019_flare_home_empty() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(19, "フレア", [], [], [H.play_skill()]),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(19, _load_skill("res://cards/019_shiranui_flare/card_skills.gd"))
	var inst_id: int = H.place_on_stage(state, 0, 19)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(19).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

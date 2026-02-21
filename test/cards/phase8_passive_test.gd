extends GdUnitTestSuite

## Phase 8: Passive スキル テスト

var H := SkillTestHelper


func _load_skill(path: String) -> BaseCardSkill:
	return (load(path) as GDScript).new()


# --- 001 ときのそら: ぬんぬん（WILD）+ 始祖（RANK_UP）---

func test_001_sora_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(1, "そら", ["SEISO"], ["LOVELY"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(1, _load_skill("res://cards/001_tokino_sora/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 1)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(1).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("WILD")


func test_001_sora_rank_up() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(1, "そら", ["SEISO"], ["LOVELY"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(1, _load_skill("res://cards/001_tokino_sora/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 1)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(1).execute_skill(ctx, 1)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("RANK_UP")


# --- 012 AZKi: Diva（WILD）---

func test_012_azki_diva_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(12, "AZKi", ["SEISO"], ["COOL"], [H.passive_skill(), H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(12, _load_skill("res://cards/012_azki/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 12)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(12).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)

	var inst: CardInstance = state.instances[inst_id]
	assert_int(inst.modifiers.size()).is_equal(1)
	assert_str(inst.modifiers[0].value).is_equal("WILD")


# --- 039 IRyS: ネフィリム（WILD）---

func test_039_irys_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(39, "IRyS", ["SEISO"], ["ENGLISH"], [H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(39, _load_skill("res://cards/039_irys/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 39)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	var result: SkillResult = sr.get_skill(39).execute_skill(ctx, 0)
	assert_int(result.status).is_equal(SkillResult.Status.DONE)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("WILD")


# --- 049 アイラニ: Iofi（WILD）+ Erofi（まつり耐性）---

func test_049_iofi_wild() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(49, "アイラニ", ["SEISO"], ["INDONESIA"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(49, _load_skill("res://cards/049_airani_iofifteen/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 49)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(49).execute_skill(ctx, 0)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("WILD")


func test_049_erofi_matsuri_immune() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(49, "アイラニ", ["SEISO"], ["INDONESIA"], [H.passive_skill(), H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(49, _load_skill("res://cards/049_airani_iofifteen/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 49)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(49).execute_skill(ctx, 1)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("MATSURI_IMMUNE")


# --- 015 星街すいせい: Hoshimatic Project（隣接にVOCAL）---

func test_015_suisei_adjacent_vocal() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(15, "すいせい", ["VOCAL"], ["COOL"], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(15, _load_skill("res://cards/015_hoshimachi_suisei/card_skills.gd"))

	var left: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 15)
	var right: int = H.place_on_stage(state, 0, 99)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(15).execute_skill(ctx, 0)

	# 左右にVOCALが付与
	assert_int(state.instances[left].modifiers.size()).is_equal(1)
	assert_str(state.instances[left].modifiers[0].value).is_equal("VOCAL")
	assert_int(state.instances[right].modifiers.size()).is_equal(1)
	assert_str(state.instances[right].modifiers[0].value).is_equal("VOCAL")
	# 自分にはなし
	assert_int(state.instances[inst_id].modifiers.size()).is_equal(0)


func test_015_suisei_edge_position() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(15, "すいせい", ["VOCAL"], ["COOL"], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(15, _load_skill("res://cards/015_hoshimachi_suisei/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 15)  # 1st position
	var right: int = H.place_on_stage(state, 0, 99)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(15).execute_skill(ctx, 0)

	assert_int(state.instances[right].modifiers.size()).is_equal(1)
	assert_str(state.instances[right].modifiers[0].value).is_equal("VOCAL")


# --- 041 一伊那尓栖: ネクロノミコン passive（隣接にEN★）---

func test_041_ina_adjacent_english() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(41, "イナ", ["OTAKU"], ["ENGLISH"], [H.passive_skill(), H.play_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(41, _load_skill("res://cards/041_ninomae_inanis/card_skills.gd"))

	var left: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 41)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(41).execute_skill(ctx, 0)

	assert_int(state.instances[left].modifiers.size()).is_equal(1)
	assert_int(state.instances[left].modifiers[0].type).is_equal(Enums.ModifierType.SUIT_ADD)
	assert_str(state.instances[left].modifiers[0].value).is_equal("ENGLISH")


# --- 055 レイネ: レイネの教室（隣接にID☽）---

func test_055_reine_adjacent_indonesia() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(55, "レイネ", ["SEXY"], ["STAFF"], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(55, _load_skill("res://cards/055_pavolia_reine/card_skills.gd"))

	var left: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 55)
	var right: int = H.place_on_stage(state, 0, 99)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(55).execute_skill(ctx, 0)

	assert_str(state.instances[left].modifiers[0].value).is_equal("INDONESIA")
	assert_str(state.instances[right].modifiers[0].value).is_equal("INDONESIA")


# --- 004 百鬼あやめ: なんも聞いとらんかった（FIRST_READY）---

func test_004_ayame_first_ready() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(4, "あやめ", ["VOCAL", "DUELIST"], ["LOVELY"], [H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(4, _load_skill("res://cards/004_nakiri_ayame/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 4)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(4).execute_skill(ctx, 0)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("FIRST_READY")


# --- 005 さくらみこ: サクラカゼ（DOUBLE_WIN）---

func test_005_miko_double_win() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(5, "みこ", ["ENJOY"], ["LOVELY"], [H.passive_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(5, _load_skill("res://cards/005_sakura_miko/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 5)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(5).execute_skill(ctx, 0)
	assert_str(state.instances[inst_id].modifiers[0].value).is_equal("DOUBLE_WIN")


# --- 013 常闇トワ: ドーム炊くよ！（protection turn_flag）---

func test_013_towa_protection() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(13, "トワ", ["CHARISMA"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(13, _load_skill("res://cards/013_tokoyami_towa/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 13)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(13).execute_skill(ctx, 0)
	assert_int(state.turn_flags.get("protection", -1)).is_equal(0)


# --- 021 雪花ラミィ: やめなー（skip_action turn_flag）---

func test_021_lamy_skip_action() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(21, "ラミィ", ["ALCOHOL"], ["COOL"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(21, _load_skill("res://cards/021_yukihana_lamy/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 21)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(21).execute_skill(ctx, 0)
	# Player 0 がプレイ → 相手(player 1) のアクションをスキップ
	assert_int(state.turn_flags.get("skip_action", -1)).is_equal(1)


# --- 027 角巻わため: わるくないよねぇ（no_stage_play turn_flag）---

func test_027_watame_no_stage_play() -> void:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(27, "わため", ["VOCAL"], ["HOT"], [H.play_skill()])
	])
	var state: GameState = env.state
	var sr: SkillRegistry = env.skill_registry
	sr.register(27, _load_skill("res://cards/027_tsunomaki_watame/card_skills.gd"))

	var inst_id: int = H.place_on_stage(state, 0, 27)

	var ctx := SkillContext.new(state, env.registry, inst_id, 0, 0, null, DiffRecorder.new())
	sr.get_skill(27).execute_skill(ctx, 0)
	assert_int(state.turn_flags.get("no_stage_play", -1)).is_equal(1)
	assert_int(state.turn_flags.get("no_stage_play_source", -1)).is_equal(inst_id)

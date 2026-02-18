class_name SkillIntegrationTest
extends GdUnitTestSuite

# --- モックスクリプトのプリロード ---
var _MockDone: GDScript = load("res://test/helpers/mock_skill_done.gd")
var _MockChoice: GDScript = load("res://test/helpers/mock_skill_with_choice.gd")
var _MockCounter: GDScript = load("res://test/helpers/mock_counter_skill.gd")


## テスト用: CardDef に skills メタデータ付き、SkillRegistry にモック登録した状態を構築。
func _setup_with_skills(skills_meta: Array, mock_skill: BaseCardSkill, card_id: int = 0) -> GameController:
	var icons: Array[String] = ["VOCAL"]
	var suits: Array[String] = ["COOL"]
	var card_def := CardDef.new(card_id, "TestCard", icons, suits, skills_meta)

	var card_registry := CardRegistry.new()
	card_registry.register(card_def)
	for i in range(1, 10):
		if i != card_id:
			var d := CardDef.new(i, "Dummy_%d" % i, icons, suits)
			card_registry.register(d)

	var sr := SkillRegistry.new()
	sr.register(card_id, mock_skill)

	var gs := GameState.new()
	var gc := GameController.new(gs, card_registry, sr)
	return gc


## プレイヤー0の手札にカードを1枚入れてステージプレイ可能にする。
func _prepare_hand_and_stage(gc: GameController, card_id: int = 0) -> int:
	var inst_id := gc.state.create_instance(card_id)
	gc.state.hands[0].append(inst_id)
	gc.state.phase = Enums.Phase.PLAY
	gc.state.current_player = 0
	return inst_id


## プレイヤーの楽屋に裏向きカードを配置。
func _prepare_backstage(gc: GameController, player: int, card_id: int = 0) -> int:
	var inst_id := gc.state.create_instance(card_id)
	gc.state.backstages[player] = inst_id
	gc.state.instances[inst_id].face_down = true
	gc.state.phase = Enums.Phase.ACTION
	gc.state.current_player = player
	return inst_id


## カウンターテスト用のセットアップ。
func _setup_counter_scenario() -> Dictionary:
	var play_mock: BaseCardSkill = _MockDone.new()
	var counter_mock: BaseCardSkill = _MockCounter.new()

	var play_skills := [{"name": "TestPlay", "type": Enums.SkillType.PLAY, "description": "test"}]
	var counter_skills := [{"name": "CounterPassive", "type": Enums.SkillType.PASSIVE, "description": "counter"}]

	var icons: Array[String] = ["VOCAL"]
	var suits: Array[String] = ["COOL"]
	var card_registry := CardRegistry.new()
	card_registry.register(CardDef.new(0, "PlayCard", icons, suits, play_skills))
	card_registry.register(CardDef.new(1, "CounterCard", icons, suits, counter_skills))
	for i in range(2, 10):
		card_registry.register(CardDef.new(i, "Dummy_%d" % i, icons, suits))

	var sr := SkillRegistry.new()
	sr.register(0, play_mock)
	sr.register(1, counter_mock)

	var gs := GameState.new()
	var gc := GameController.new(gs, card_registry, sr)

	# 相手ステージにカウンターカード配置
	var counter_inst_id := gs.create_instance(1)
	gs.stages[1].append(counter_inst_id)
	gs.instances[counter_inst_id].face_down = false

	# プレイヤー0の手札にプレイカード
	var play_inst_id := gs.create_instance(0)
	gs.hands[0].append(play_inst_id)
	gs.phase = Enums.Phase.PLAY
	gs.current_player = 0

	return {"gc": gc, "gs": gs, "play_inst_id": play_inst_id, "counter_inst_id": counter_inst_id}


# ===== 基本フロー =====


func test_play_to_stage_triggers_play_skill() -> void:
	var mock: BaseCardSkill = _MockDone.new()
	var skills_meta := [{"name": "TestPlay", "type": Enums.SkillType.PLAY, "description": "test"}]
	var gc := _setup_with_skills(skills_meta, mock)
	var inst_id := _prepare_hand_and_stage(gc)

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "stage"})

	assert_int(gc.state.current_player).is_equal(1)
	assert_bool(gc.state.skill_stack.is_empty()).is_true()


func test_play_to_backstage_no_skill() -> void:
	var mock: BaseCardSkill = _MockDone.new()
	var skills_meta := [{"name": "TestPlay", "type": Enums.SkillType.PLAY, "description": "test"}]
	var gc := _setup_with_skills(skills_meta, mock)
	var inst_id := _prepare_hand_and_stage(gc)

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "backstage"})

	assert_int(gc.state.current_player).is_equal(1)
	assert_bool(gc.state.skill_stack.is_empty()).is_true()


func test_open_triggers_play_skill() -> void:
	var mock: BaseCardSkill = _MockDone.new()
	var skills_meta := [{"name": "TestPlay", "type": Enums.SkillType.PLAY, "description": "test"}]
	var gc := _setup_with_skills(skills_meta, mock)
	var inst_id := _prepare_backstage(gc, 0)

	gc.apply_action({"type": Enums.ActionType.OPEN, "instance_id": inst_id})

	assert_int(gc.state.current_player).is_equal(0)
	assert_int(gc.state.phase).is_equal(Enums.Phase.ACTION)
	assert_bool(gc.state.skill_stack.is_empty()).is_true()


func test_no_skill_registry_backward_compat() -> void:
	var card_registry := CardFactory.create_test_registry(10)
	var gs := GameState.new()
	var gc := GameController.new(gs, card_registry)

	for i in range(10):
		var inst_id := gs.create_instance(i)
		gs.deck.append(inst_id)

	gc.start_turn()
	assert_int(gs.phase).is_equal(Enums.Phase.ACTION)
	gc.apply_action({"type": Enums.ActionType.PASS})
	assert_int(gs.phase).is_equal(Enums.Phase.PLAY)


# ===== PendingChoice =====


func test_skill_with_choice_pauses_resolution() -> void:
	var mock: BaseCardSkill = _MockChoice.new()
	var skills_meta := [{"name": "TestPlay", "type": Enums.SkillType.PLAY, "description": "test"}]
	var gc := _setup_with_skills(skills_meta, mock)
	var inst_id := _prepare_hand_and_stage(gc)

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "stage"})

	assert_bool(gc.is_waiting_for_choice()).is_true()
	assert_int(gc.state.pending_choices.size()).is_equal(1)
	assert_int(gc.state.current_player).is_equal(0)


func test_submit_choice_resumes_and_ends_turn() -> void:
	var mock: BaseCardSkill = _MockChoice.new()
	var skills_meta := [{"name": "TestPlay", "type": Enums.SkillType.PLAY, "description": "test"}]
	var gc := _setup_with_skills(skills_meta, mock)
	var inst_id := _prepare_hand_and_stage(gc)

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "stage"})
	assert_bool(gc.is_waiting_for_choice()).is_true()

	gc.submit_choice(0, 10)

	assert_bool(gc.is_waiting_for_choice()).is_false()
	assert_int(gc.state.current_player).is_equal(1)
	assert_bool(gc.state.skill_stack.is_empty()).is_true()


# ===== アクションスキル =====


func test_action_skill_in_available_actions() -> void:
	var mock: BaseCardSkill = _MockDone.new()
	var skills_meta := [
		{"name": "TestAction", "type": Enums.SkillType.ACTION, "description": "test"},
	]
	var gc := _setup_with_skills(skills_meta, mock)

	var inst_id := gc.state.create_instance(0)
	gc.state.stages[0].append(inst_id)
	gc.state.instances[inst_id].face_down = false
	gc.state.phase = Enums.Phase.ACTION
	gc.state.current_player = 0

	var actions := gc.get_available_actions()
	var has_activate := false
	for a in actions:
		if a["type"] == Enums.ActionType.ACTIVATE_SKILL:
			has_activate = true
			assert_int(a["instance_id"]).is_equal(inst_id)
			assert_int(a["skill_index"]).is_equal(0)
	assert_bool(has_activate).is_true()


func test_action_skill_once_per_turn() -> void:
	var mock: BaseCardSkill = _MockDone.new()
	var skills_meta := [
		{"name": "TestAction", "type": Enums.SkillType.ACTION, "description": "test"},
	]
	var gc := _setup_with_skills(skills_meta, mock)

	var inst_id := gc.state.create_instance(0)
	gc.state.stages[0].append(inst_id)
	gc.state.instances[inst_id].face_down = false
	gc.state.phase = Enums.Phase.ACTION
	gc.state.current_player = 0

	gc.apply_action({"type": Enums.ActionType.ACTIVATE_SKILL, "instance_id": inst_id, "skill_index": 0})

	var actions := gc.get_available_actions()
	for a in actions:
		if a["type"] == Enums.ActionType.ACTIVATE_SKILL:
			fail("ACTIVATE_SKILL should not appear after use")


func test_activate_skill_stays_in_action_phase() -> void:
	var mock: BaseCardSkill = _MockDone.new()
	var skills_meta := [
		{"name": "TestAction", "type": Enums.SkillType.ACTION, "description": "test"},
	]
	var gc := _setup_with_skills(skills_meta, mock)

	var inst_id := gc.state.create_instance(0)
	gc.state.stages[0].append(inst_id)
	gc.state.instances[inst_id].face_down = false
	gc.state.phase = Enums.Phase.ACTION
	gc.state.current_player = 0

	gc.apply_action({"type": Enums.ActionType.ACTIVATE_SKILL, "instance_id": inst_id, "skill_index": 0})

	assert_int(gc.state.phase).is_equal(Enums.Phase.ACTION)
	assert_int(gc.state.current_player).is_equal(0)


# ===== カウンター =====


func test_counter_choice_offered() -> void:
	var d := _setup_counter_scenario()
	var gc: GameController = d["gc"]
	var gs: GameState = d["gs"]
	var play_inst_id: int = d["play_inst_id"]
	var counter_inst_id: int = d["counter_inst_id"]

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": play_inst_id, "target": "stage"})

	assert_bool(gc.is_waiting_for_choice()).is_true()
	assert_int(gs.pending_choices.size()).is_equal(1)
	var pc: PendingChoice = gs.pending_choices[0]
	assert_bool(pc.valid_targets.has(counter_inst_id)).is_true()
	assert_bool(pc.valid_targets.has(-1)).is_true()


func test_counter_pass() -> void:
	var d := _setup_counter_scenario()
	var gc: GameController = d["gc"]
	var gs: GameState = d["gs"]
	var play_inst_id: int = d["play_inst_id"]

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": play_inst_id, "target": "stage"})
	assert_bool(gc.is_waiting_for_choice()).is_true()

	gc.submit_choice(0, -1)

	assert_int(gs.current_player).is_equal(1)
	assert_bool(gs.skill_stack.is_empty()).is_true()


func test_counter_accepted() -> void:
	var d := _setup_counter_scenario()
	var gc: GameController = d["gc"]
	var gs: GameState = d["gs"]
	var play_inst_id: int = d["play_inst_id"]
	var counter_inst_id: int = d["counter_inst_id"]

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": play_inst_id, "target": "stage"})
	assert_bool(gc.is_waiting_for_choice()).is_true()

	gc.submit_choice(0, counter_inst_id)

	assert_int(gs.current_player).is_equal(1)
	assert_bool(gs.skill_stack.is_empty()).is_true()


func test_no_counter_when_no_passive() -> void:
	var mock: BaseCardSkill = _MockDone.new()
	var skills_meta := [{"name": "TestPlay", "type": Enums.SkillType.PLAY, "description": "test"}]
	var gc := _setup_with_skills(skills_meta, mock)

	var dummy_inst_id := gc.state.create_instance(1)
	gc.state.stages[1].append(dummy_inst_id)
	gc.state.instances[dummy_inst_id].face_down = false

	var inst_id := _prepare_hand_and_stage(gc)
	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "stage"})

	assert_bool(gc.is_waiting_for_choice()).is_false()
	assert_int(gc.state.current_player).is_equal(1)

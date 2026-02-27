extends GdUnitTestSuite

var H := SkillTestHelper


func _create_env() -> Dictionary:
	return H.create_test_env([
		H.make_card_def(1, "Test", ["VOCAL"], ["COOL"], [H.play_skill()]),
	])


func test_field_effect_promoted_after_tick() -> void:
	var env: Dictionary = _create_env()
	var state: GameState = env.state
	var controller: GameController = env.controller

	# lifetime=1 のエフェクトを追加
	state.field_effects.append(FieldEffect.new("skip_action", 0, -1, 1))

	# まだアクティブ
	assert_bool(state.has_field_effect("skip_action", 0)).is_true()

	# デッキにカードを入れてターン開始可能にする
	H.place_in_deck_top(state, 1)
	controller.start_turn()

	# tick 後: lifetime 1→0 にデクリメントされるがまだ存在する
	assert_bool(state.has_field_effect("skip_action", 0)).is_true()

	# もう1ターン: lifetime=0 が除去される
	state.current_player = 0
	H.place_in_deck_top(state, 1)
	controller.start_turn()
	assert_bool(state.has_field_effect("skip_action", 0)).is_false()


func test_skip_action_skips_to_play_phase() -> void:
	var env: Dictionary = _create_env()
	var state: GameState = env.state
	var controller: GameController = env.controller

	state.field_effects.append(FieldEffect.new("skip_action", 0, -1, 1))
	H.place_in_deck_top(state, 1)
	state.current_player = 0
	controller.start_turn()

	# ACTION ではなく PLAY にスキップされている
	assert_int(state.phase).is_equal(Enums.Phase.PLAY)


func test_no_stage_play_removes_stage_targets() -> void:
	var env: Dictionary = _create_env()
	var state: GameState = env.state
	var controller: GameController = env.controller

	# Player 0 のステージは空（<3）
	state.field_effects.append(FieldEffect.new("no_stage_play", 0, -1, 1))
	H.place_in_hand(state, 0, 1)
	H.place_in_deck_top(state, 1)
	state.current_player = 0
	controller.start_turn()

	# PLAY フェーズに進める
	controller.apply_action({"type": Enums.ActionType.PASS})
	assert_int(state.phase).is_equal(Enums.Phase.PLAY)

	var actions: Array = controller.get_available_actions()
	# ステージへのプレイは不可（stage target なし）
	for act in actions:
		if act.get("type") == Enums.ActionType.PLAY_CARD:
			assert_str(act.get("target", "")).is_equal("backstage")


func test_source_cleanup_on_leave_zone() -> void:
	var env: Dictionary = _create_env()
	var state: GameState = env.state
	var controller: GameController = env.controller

	var inst_id: int = H.place_on_stage(state, 0, 1)
	state.field_effects.append(FieldEffect.new("no_stage_play", 1, inst_id, 1))
	assert_bool(state.has_field_effect("no_stage_play", 1)).is_true()

	# カードをステージから除外（ラウンドクリーンアップを模倣）
	state.stages[0].erase(inst_id)
	state.removed.append(inst_id)
	# _fire_trigger 経由でソースクリーンアップ
	controller._fire_trigger(Enums.TriggerEvent.CARD_LEFT_ZONE, {"instance_id": inst_id})

	assert_bool(state.has_field_effect("no_stage_play", 1)).is_false()


func test_lifetime_3_survives_3_turns() -> void:
	var env: Dictionary = _create_env()
	var state: GameState = env.state
	var controller: GameController = env.controller

	state.field_effects.append(FieldEffect.new("protection", 0, -1, 3))

	# 3ターン分 tick: 3→2→1→0
	for i in range(3):
		H.place_in_deck_top(state, 1)
		state.current_player = 0
		controller.start_turn()

	# 3回目の tick 後: lifetime=0 でまだ存在
	assert_bool(state.has_field_effect("protection", 0)).is_true()

	# 4回目の tick: lifetime=0 が除去される
	H.place_in_deck_top(state, 1)
	state.current_player = 0
	controller.start_turn()
	assert_bool(state.has_field_effect("protection", 0)).is_false()


func test_permanent_effect_not_decremented() -> void:
	var env: Dictionary = _create_env()
	var state: GameState = env.state
	var controller: GameController = env.controller

	state.field_effects.append(FieldEffect.new("protection", 0, -1, -1))

	# 複数ターン経過しても永続
	for i in range(5):
		H.place_in_deck_top(state, 1)
		state.current_player = 0
		controller.start_turn()

	assert_bool(state.has_field_effect("protection", 0)).is_true()
	# lifetime は -1 のまま
	var fe: FieldEffect = state.field_effects[0]
	assert_int(fe.lifetime).is_equal(-1)


func test_to_dict_from_dict_roundtrip() -> void:
	var fe := FieldEffect.new("skip_action", 1, 42, 3)
	var d: Dictionary = fe.to_dict()
	var fe2: FieldEffect = FieldEffect.from_dict(d)

	assert_str(fe2.type).is_equal("skip_action")
	assert_int(fe2.target_player).is_equal(1)
	assert_int(fe2.source_instance_id).is_equal(42)
	assert_int(fe2.lifetime).is_equal(3)

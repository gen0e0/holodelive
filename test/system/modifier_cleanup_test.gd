class_name ModifierCleanupTest
extends GdUnitTestSuite


func _setup_game_with_modifiers() -> GameController:
	var registry := CardRegistry.new()
	for i in range(10):
		var icons: Array[String] = ["VOCAL"]
		var suits: Array[String] = ["COOL"]
		registry.register(CardDef.new(i, "Card_%d" % i, icons, suits))

	var state := GameState.new()
	state.phase = Enums.Phase.ACTION
	state.current_player = 0

	# インスタンスを作成
	for i in range(6):
		var inst := CardInstance.new(i, i % 10)
		state.instances[i] = inst

	return GameController.new(state, registry)


func test_cleanup_removes_non_persistent_modifiers() -> void:
	var ctrl := _setup_game_with_modifiers()
	var source_id := 0
	var target_id := 1

	# source_id=0 からの非永続 Modifier を target に付与
	var mod := Modifier.new(Enums.ModifierType.ICON_ADD, "DANCE", source_id, false)
	ctrl.state.instances[target_id].modifiers.append(mod)
	assert_int(ctrl.state.instances[target_id].modifiers.size()).is_equal(1)

	# source カードをゾーンから離脱させるトリガーを手動発火
	ctrl._fire_trigger(Enums.TriggerEvent.CARD_LEFT_ZONE, {"instance_id": source_id})

	assert_int(ctrl.state.instances[target_id].modifiers.size()).is_equal(0)


func test_cleanup_keeps_persistent_modifiers() -> void:
	var ctrl := _setup_game_with_modifiers()
	var source_id := 0
	var target_id := 1

	# persistent = true
	var mod := Modifier.new(Enums.ModifierType.ICON_ADD, "DANCE", source_id, true)
	ctrl.state.instances[target_id].modifiers.append(mod)

	ctrl._fire_trigger(Enums.TriggerEvent.CARD_LEFT_ZONE, {"instance_id": source_id})

	assert_int(ctrl.state.instances[target_id].modifiers.size()).is_equal(1)


func test_cleanup_only_affects_matching_source() -> void:
	var ctrl := _setup_game_with_modifiers()

	# source=0 の非永続と source=2 の非永続を target=1 に付与
	var mod_a := Modifier.new(Enums.ModifierType.ICON_ADD, "DANCE", 0, false)
	var mod_b := Modifier.new(Enums.ModifierType.SUIT_ADD, "HOT", 2, false)
	ctrl.state.instances[1].modifiers.append(mod_a)
	ctrl.state.instances[1].modifiers.append(mod_b)

	# source=0 が離脱
	ctrl._fire_trigger(Enums.TriggerEvent.CARD_LEFT_ZONE, {"instance_id": 0})

	# source=0 の Modifier だけ除去、source=2 は残る
	assert_int(ctrl.state.instances[1].modifiers.size()).is_equal(1)
	var remaining: Modifier = ctrl.state.instances[1].modifiers[0]
	assert_int(remaining.source_instance_id).is_equal(2)


func test_round_cleanup_triggers_modifier_cleanup() -> void:
	var ctrl := _setup_game_with_modifiers()

	# Player 0 のステージにカード配置
	ctrl.state.stages[0][0] = 0
	ctrl.state.stages[0][1] = 1
	ctrl.state.stages[0][2] = 2
	# Player 1 のステージにカード配置
	ctrl.state.stages[1][0] = 3
	ctrl.state.stages[1][1] = 4
	ctrl.state.stages[1][2] = 5

	# instance=0 (ステージ上) からの非永続 Modifier を instance=3 に付与
	# instance=3 もステージ上なのでラウンドクリーンアップで両方離脱
	var mod := Modifier.new(Enums.ModifierType.ICON_ADD, "SEXY", 0, false)
	ctrl.state.instances[3].modifiers.append(mod)

	# ラウンドクリーンアップ実行
	ctrl._do_round_cleanup()

	# ステージカードが離脱したので Modifier がクリーンアップされている
	assert_int(ctrl.state.instances[3].modifiers.size()).is_equal(0)

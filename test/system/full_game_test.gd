class_name FullGameTest
extends GdUnitTestSuite

## 小さいデッキ（12枚）で1ゲーム完走する統合テスト。
## 各ターン: start_turn → PASS(ACTION) → PLAY_CARD(stage) を繰り返す。
## ステージが3枚埋まったらライブ→ラウンド勝利を繰り返し、3勝でゲーム終了。
func test_full_game_completes() -> void:
	var registry := CardFactory.create_test_registry(40)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var state := GameSetup.setup_game(registry, rng)
	var ctrl := GameController.new(state, registry)

	var max_turns := 200
	var turn_count := 0

	while not ctrl.is_game_over() and turn_count < max_turns:
		turn_count += 1
		var live_triggered := ctrl.start_turn()
		if live_triggered:
			# ライブが発生 → ラウンド処理済み
			continue

		# ACTION フェーズ: パス
		ctrl.apply_action({"type": Enums.ActionType.PASS})

		# PLAY フェーズ: 有効なアクションから最初のプレイを選ぶ
		var actions := ctrl.get_available_actions()
		var played := false
		for a in actions:
			if a["type"] == Enums.ActionType.PLAY_CARD and a.get("target", "") == "stage":
				ctrl.apply_action(a)
				played = true
				break
		if not played:
			# ステージに空きがなければ楽屋 or パス
			for a in actions:
				if a["type"] == Enums.ActionType.PLAY_CARD:
					ctrl.apply_action(a)
					played = true
					break
			if not played:
				ctrl.apply_action({"type": Enums.ActionType.PASS})

	assert_bool(ctrl.is_game_over()).is_true()
	var winner := ctrl.get_winner()
	assert_int(winner).is_greater_equal(0)
	assert_int(winner).is_less_equal(1)
	assert_int(ctrl.state.round_wins[winner]).is_greater_equal(3)

	# Verify we didn't hit max turns
	assert_bool(turn_count < max_turns).is_true()


## ゲーム中のカード数整合性を検証。
func test_full_game_card_consistency() -> void:
	var registry := CardFactory.create_test_registry(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var state := GameSetup.setup_game(registry, rng)
	var ctrl := GameController.new(state, registry)
	var total_cards := state.instances.size()

	var max_turns := 150
	var turn_count := 0

	while not ctrl.is_game_over() and turn_count < max_turns:
		turn_count += 1
		var live_triggered := ctrl.start_turn()
		if live_triggered:
			continue

		ctrl.apply_action({"type": Enums.ActionType.PASS})

		var actions := ctrl.get_available_actions()
		var played := false
		for a in actions:
			if a["type"] == Enums.ActionType.PLAY_CARD and a.get("target", "") == "stage":
				ctrl.apply_action(a)
				played = true
				break
		if not played:
			for a in actions:
				if a["type"] == Enums.ActionType.PLAY_CARD:
					ctrl.apply_action(a)
					played = true
					break
			if not played:
				ctrl.apply_action({"type": Enums.ActionType.PASS})

		# カウント検証: 全ゾーンのカード数合計はインスタンス数を超えない
		var zone_count: int = state.deck.size() + state.home.size() + state.removed.size()
		for p in range(2):
			zone_count += state.hands[p].size()
			for s in range(3):
				if state.stages[p][s] != -1:
					zone_count += 1
			if state.backstages[p] != -1:
				zone_count += 1
		assert_int(zone_count).is_less_equal(state.instances.size())

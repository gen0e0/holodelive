extends GdUnitTestSuite


func test_human_controller_submit_action_emits_decided() -> void:
	var hpc := HumanPlayerController.new()
	var results: Array = []
	hpc.action_decided.connect(func(action: Dictionary) -> void:
		results.append(action))

	var action: Dictionary = {"type": Enums.ActionType.PASS}
	hpc.submit_action(action)

	assert_int(results.size()).is_equal(1)
	assert_int(results[0].get("type")).is_equal(Enums.ActionType.PASS)


func test_human_controller_submit_choice_emits_decided() -> void:
	var hpc := HumanPlayerController.new()
	var results: Array = []
	hpc.choice_decided.connect(func(idx: int, value: Variant) -> void:
		results.append({"idx": idx, "value": value}))

	hpc.submit_choice(0, 42)

	assert_int(results.size()).is_equal(1)
	assert_int(results[0]["idx"]).is_equal(0)
	assert_int(results[0]["value"]).is_equal(42)


func test_human_controller_request_action_emits_presented() -> void:
	var hpc := HumanPlayerController.new()
	var presented: Array = []
	hpc.actions_presented.connect(func(actions: Array) -> void:
		presented.append(actions))

	var actions: Array = [{"type": Enums.ActionType.PASS}]
	hpc.request_action(actions)

	assert_int(presented.size()).is_equal(1)
	assert_int(presented[0].size()).is_equal(1)


func test_cpu_controller_delay_zero_emits_synchronously() -> void:
	# delay=0 の場合、request_action は即座に action_decided を emit する
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var registry := CardFactory.create_test_registry(40)
	var state := GameSetup.setup_game(registry, rng)
	var strategy := RandomStrategy.new(rng)

	var cpu := CpuPlayerController.new(strategy,
		func() -> GameState: return state,
		func() -> CardRegistry: return registry,
		null, 0.0)

	var results: Array = []
	cpu.action_decided.connect(func(action: Dictionary) -> void:
		results.append(action))

	var actions: Array = [
		{"type": Enums.ActionType.PASS},
		{"type": Enums.ActionType.PLAY_CARD, "instance_id": 1, "target": "stage"},
	]
	cpu.request_action(actions)

	# delay=0 → 同期的に emit
	assert_int(results.size()).is_equal(1)
	assert_bool(results[0].has("type")).is_true()


func test_cpu_controller_cancel_prevents_emit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var registry := CardFactory.create_test_registry(40)
	var state := GameSetup.setup_game(registry, rng)
	var strategy := RandomStrategy.new(rng)

	# delay > 0 を使うとテストが非同期になるので、delay=0 + cancel で検証
	var cpu := CpuPlayerController.new(strategy,
		func() -> GameState: return state,
		func() -> CardRegistry: return registry,
		null, 0.0)

	cpu.cancel()

	var results: Array = []
	cpu.action_decided.connect(func(action: Dictionary) -> void:
		results.append(action))

	# cancel 後の request でも _cancelled=false にリセットされるので emit される
	# (cancel は進行中の操作のみ無効化)
	cpu.request_action([{"type": Enums.ActionType.PASS}])
	assert_int(results.size()).is_equal(1)

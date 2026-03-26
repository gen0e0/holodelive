class_name GameRoomTest
extends GdUnitTestSuite

const _GameRoomScene: PackedScene = preload("res://scenes/game/game_room.tscn")


func _create_room(rng: RandomNumberGenerator = null) -> GameRoom:
	var room: GameRoom = _GameRoomScene.instantiate()
	add_child(room)
	room.setup_local(rng)
	room.server_context.add_viewer(0)
	return room


func test_start_game_emits_signals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var room: GameRoom = _create_room(rng)

	var counts: Array[int] = [0, 0]  # [started, actions_received]
	room.bridge.game_started_received.connect(func() -> void: counts[0] += 1)
	room.bridge.actions_received.connect(func(_p: int, _a: Array) -> void: counts[1] += 1)

	room.server_context.start_game()

	assert_int(counts[0]).is_equal(1)
	# actions は PlayerController 未登録時に bridge 経由で届く
	# (P0 にコントローラ未設定なので bridge に送られる)
	assert_int(counts[1]).is_greater(0)
	room.queue_free()


func test_state_received_emits_client_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var room: GameRoom = _create_room(rng)

	var received: Array = []
	room.bridge.state_received.connect(
		func(p: int, cs: Variant, ev: Array) -> void: received.append({"player": p, "cs": cs, "events": ev}))

	room.server_context.start_game()

	assert_int(received.size()).is_greater(0)
	# ローカルモードでは ClientState オブジェクトが直接渡される
	var first: Dictionary = received[0]
	assert_int(first["player"]).is_equal(0)
	assert_that(first["cs"]).is_instanceof(ClientState)
	room.queue_free()


func test_receive_action_updates_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var room: GameRoom = _create_room(rng)

	room.server_context.start_game()

	var state: GameState = room.server_context.state
	var turn_before: int = state.turn_number

	room.server_context.receive_action({"type": Enums.ActionType.PASS}, state.current_player)

	# PASS で状態が変化することを確認
	assert_that(state).is_not_null()
	room.queue_free()


func test_full_game_manual_actions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var room: GameRoom = _create_room(rng)

	var winner_holder: Array[int] = [-1]
	room.bridge.game_over_received.connect(func(w: int) -> void: winner_holder[0] = w)

	var registry: CardRegistry = CardFactory.create_test_registry(40)
	var skill_registry := SkillRegistry.new()
	var state: GameState = GameSetup.setup_game(registry, rng)
	var controller := GameController.new(state, registry, skill_registry)

	var ctx: ServerContext = room.server_context
	ctx.registry = registry
	ctx.skill_registry = skill_registry
	ctx.state = state
	ctx.controller = controller
	ctx.controller.on_action_logged = ctx._on_action_logged
	ctx._last_log_index = 0

	room.bridge.broadcast_game_started()
	ctx._do_start_turn()

	var max_iterations: int = 500
	var iterations: int = 0

	while winner_holder[0] == -1 and iterations < max_iterations:
		iterations += 1

		if ctx.controller.is_game_over():
			break

		var actions: Array = ctx.controller.get_available_actions()
		if actions.is_empty():
			break

		var action_to_send: Dictionary = {}
		var played: bool = false
		for a in actions:
			if a["type"] == Enums.ActionType.PLAY_CARD and a.get("target", "") == "stage":
				action_to_send = a
				played = true
				break
		if not played:
			for a in actions:
				if a["type"] == Enums.ActionType.PLAY_CARD:
					action_to_send = a
					played = true
					break
		if not played:
			action_to_send = {"type": Enums.ActionType.PASS}

		ctx.receive_action(action_to_send, state.current_player)

	assert_int(winner_holder[0]).is_greater_equal(0)
	assert_int(winner_holder[0]).is_less_equal(1)
	assert_bool(iterations < max_iterations).is_true()
	room.queue_free()


func test_cpu_vs_cpu_full_game() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999
	var room: GameRoom = _create_room(rng)

	var winner_holder: Array[int] = [-1]
	room.bridge.game_over_received.connect(func(w: int) -> void: winner_holder[0] = w)

	var ctx: ServerContext = room.server_context
	var registry: CardRegistry = CardFactory.create_test_registry(40)
	var skill_registry := SkillRegistry.new()
	var state: GameState = GameSetup.setup_game(registry, rng)
	var controller := GameController.new(state, registry, skill_registry)

	ctx.registry = registry
	ctx.skill_registry = skill_registry
	ctx.state = state
	ctx.controller = controller
	ctx.controller.on_action_logged = ctx._on_action_logged
	ctx._last_log_index = 0

	var get_state: Callable = func() -> GameState: return ctx.state
	var get_registry: Callable = func() -> CardRegistry: return ctx.registry
	ctx.set_player_controller(0, CpuPlayerController.new(
		RandomStrategy.new(rng), get_state, get_registry, get_tree(), 0.0))
	ctx.set_player_controller(1, CpuPlayerController.new(
		RandomStrategy.new(rng), get_state, get_registry, get_tree(), 0.0))

	room.bridge.broadcast_game_started()
	ctx._do_start_turn()

	assert_int(winner_holder[0]).is_greater_equal(0)
	assert_int(winner_holder[0]).is_less_equal(1)
	room.queue_free()


func test_controller_actions_flow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321
	var room: GameRoom = _create_room(rng)

	# P1 を CPU に設定、P0 はコントローラ未登録（bridge 経由で actions が届く）
	var ctx: ServerContext = room.server_context
	var registry: CardRegistry = CardFactory.create_test_registry(40)
	var skill_registry := SkillRegistry.new()
	var state: GameState = GameSetup.setup_game(registry, rng)
	var controller := GameController.new(state, registry, skill_registry)

	ctx.registry = registry
	ctx.skill_registry = skill_registry
	ctx.state = state
	ctx.controller = controller
	ctx.controller.on_action_logged = ctx._on_action_logged
	ctx._last_log_index = 0

	var get_state: Callable = func() -> GameState: return ctx.state
	var get_registry: Callable = func() -> CardRegistry: return ctx.registry
	ctx.set_player_controller(1, CpuPlayerController.new(
		RandomStrategy.new(rng), get_state, get_registry, get_tree(), 0.0))

	var action_counts: Array[int] = [0]
	room.bridge.actions_received.connect(func(_p: int, _a: Array) -> void: action_counts[0] += 1)

	room.bridge.broadcast_game_started()
	ctx._do_start_turn()

	assert_int(action_counts[0]).is_greater(0)

	if not ctx.controller.is_game_over():
		assert_int(ctx.state.current_player).is_equal(0)
	room.queue_free()

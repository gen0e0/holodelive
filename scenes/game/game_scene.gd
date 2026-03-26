extends Control

## ネットワーク対戦シーン。GameRoom + GameScreen を使用してホスト/ゲストの両方に対応。
## LobbyScene から遷移され、NetworkManager が接続済みであることを前提とする。

const _GameRoomScene: PackedScene = preload("res://scenes/game/game_room.tscn")
const _GameScreenScene: PackedScene = preload("res://scenes/gui/game_screen.tscn")

var _game_room: GameRoom
var _game_screen: GameScreen
var _my_player: int = -1
var _p0_controller: HumanPlayerController


func _ready() -> void:
	var nm: Node = get_node("/root/NetworkManager")

	# GameRoom インスタンス化
	_game_room = _GameRoomScene.instantiate()
	add_child(_game_room)

	# GameScreen インスタンス化（フルスクリーン）
	_game_screen = _GameScreenScene.instantiate()
	_game_screen.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_game_screen)

	if nm.is_host:
		_my_player = 0
		_game_room.setup_host()

		# ホスト: P0 に HumanPlayerController を登録
		_p0_controller = HumanPlayerController.new()
		_game_room.server_context.set_player_controller(0, _p0_controller)

		# P1（リモート）のビューアーを登録（P0 は connect_game_room 内で登録される）
		_game_room.server_context.add_viewer(1)

		# 切断ハンドラ
		nm.player_disconnected.connect(_on_player_disconnected)

		# GameScreen 接続（コントローラ付き）
		_game_screen.connect_game_room(_game_room, _p0_controller, 0)

		# ゲスト準備完了を待って開始
		await get_tree().create_timer(1.0).timeout
		_game_room.server_context.start_game()
	else:
		_my_player = 1
		_game_room.setup_guest()

		# ゲスト: コントローラなし（Bridge 経由で操作）
		_game_screen.connect_game_room(_game_room, null, 1)


# =============================================================================
# ネットワーク切断
# =============================================================================

func _on_player_disconnected(peer_id: int) -> void:
	if not _game_room or not _game_room.server_context:
		return
	var nm: Node = get_node("/root/NetworkManager")
	var player_index: int = nm.get_player_index(peer_id)
	if player_index < 0:
		return

	var ctx: ServerContext = _game_room.server_context
	var get_state: Callable = func() -> GameState: return ctx.state
	var get_registry: Callable = func() -> CardRegistry: return ctx.registry
	var cpu := CpuPlayerController.new(
		RandomStrategy.new(), get_state, get_registry, get_tree(), 0.5)
	ctx.set_player_controller(player_index, cpu)

	# CPU が今すぐ行動する必要があるかチェック
	if not ctx.controller.is_game_over():
		if ctx.controller.is_waiting_for_choice():
			var pc: PendingChoice = ChoiceHelper.get_active_pending_choice(ctx.state.pending_choices)
			if pc and pc.target_player == player_index:
				var choice_data: Dictionary = ChoiceHelper.make_choice_data(pc, ctx.state, ctx.registry)
				cpu.request_choice(choice_data)
		elif ctx.state.current_player == player_index:
			var actions: Array = ctx.controller.get_available_actions()
			cpu.request_action(actions)

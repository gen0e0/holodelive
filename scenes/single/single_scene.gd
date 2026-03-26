extends Control

## シングルプレイヤーシーン。GameRoom + GameScreen で CPU 対戦。

const _GameRoomScene: PackedScene = preload("res://scenes/game/game_room.tscn")
const _GameScreenScene: PackedScene = preload("res://scenes/gui/game_screen.tscn")

var _game_room: GameRoom
var _game_screen: GameScreen


func _ready() -> void:
	# GameRoom
	_game_room = _GameRoomScene.instantiate()
	add_child(_game_room)
	_game_room.setup_local()

	var ctx: ServerContext = _game_room.server_context

	# P1 は CPU
	var get_state: Callable = func() -> GameState: return ctx.state
	var get_registry: Callable = func() -> CardRegistry: return ctx.registry
	ctx.set_player_controller(1, CpuPlayerController.new(
		RandomStrategy.new(), get_state, get_registry, get_tree(), 0.5))

	# GameScreen（フルスクリーン）
	_game_screen = _GameScreenScene.instantiate()
	_game_screen.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_game_screen)
	_game_screen.connect_game_room(_game_room, 0)

	ctx.start_game()

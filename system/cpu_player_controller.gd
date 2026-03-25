class_name CpuPlayerController
extends PlayerController

## CPU操作用の PlayerController。
## CpuStrategy を使って判断し、オプションの遅延後に決定シグナルを返す。
## delay=0 の場合は await なしで即座に emit する（同期テスト対応）。
## delay>0 の場合は create_timer で非同期（フレーム落ち防止・自然な演出）。
##
## state/registry は Callable で遅延取得する（set_cpu_player 時点で未初期化の場合に対応）。

var _strategy: CpuStrategy
var _get_state: Callable   # () -> GameState
var _get_registry: Callable  # () -> CardRegistry
var _tree: SceneTree
var _delay: float
var _cancelled: bool = false


func _init(strategy: CpuStrategy, get_state: Callable, get_registry: Callable,
		tree: SceneTree, delay: float = 0.0) -> void:
	_strategy = strategy
	_get_state = get_state
	_get_registry = get_registry
	_tree = tree
	_delay = delay


func request_action(actions: Array) -> void:
	_cancelled = false
	var result: Dictionary = _strategy.pick_action(actions, _get_state.call(), _get_registry.call())
	if result.is_empty():
		return
	if _delay > 0 and _tree != null:
		await _tree.create_timer(_delay).timeout
		if _cancelled:
			return
	action_decided.emit(result)


func request_choice(choice_data: Dictionary) -> void:
	_cancelled = false
	var result: Dictionary = _strategy.pick_choice(choice_data, _get_state.call(), _get_registry.call())
	if result.is_empty():
		return
	if _delay > 0 and _tree != null:
		await _tree.create_timer(_delay).timeout
		if _cancelled:
			return
	choice_decided.emit(result["choice_index"], result["value"])


func cancel() -> void:
	_cancelled = true

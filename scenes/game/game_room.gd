class_name GameRoom
extends Node

## ゲームルーム: ServerContext + GameBridge + Client の共通構造。
## ローカル/ホスト/ゲストの3モードで初期化する。
## tscn で定義されたノード構造を前提とする。

enum Mode { LOCAL, HOST, GUEST }

var mode: Mode = Mode.LOCAL

@onready var server_context: ServerContext = $ServerContext
@onready var bridge: GameBridge = $GameBridge


func setup_local(rng: RandomNumberGenerator = null) -> void:
	mode = Mode.LOCAL
	bridge.is_local = true
	server_context.setup(bridge, rng)


func setup_host(rng: RandomNumberGenerator = null) -> void:
	mode = Mode.HOST
	bridge.is_local = false
	server_context.setup(bridge, rng)


func setup_guest() -> void:
	mode = Mode.GUEST
	bridge.is_local = false
	# ゲストでは ServerContext は不使用
	server_context.queue_free()

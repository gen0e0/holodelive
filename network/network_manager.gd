extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal connection_succeeded()
signal game_ready()

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var _peer_to_player: Dictionary = {}  # {peer_id: int -> player_index: int}

var _server: GameServer = null
var _client: GameClient = null


func host_game(port: int = 7000) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, 1)  # max 1 guest
	if err != OK:
		peer = null
		return err

	multiplayer.multiplayer_peer = peer
	is_host = true

	# Host is always player 0
	_peer_to_player[1] = 0

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Create server + client for host
	_server = GameServer.new()
	_server.name = "GameServer"
	add_child(_server)

	_client = GameClient.new()
	_client.name = "GameClient"
	add_child(_client)

	print("[NetworkManager] Hosting on port %d" % port)
	return OK


func join_game(address: String, port: int = 7000) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		peer = null
		return err

	multiplayer.multiplayer_peer = peer
	is_host = false

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# RPC routing stub — Godot matches RPC calls by node path,
	# so the guest needs a GameServer node at the same path as the host's.
	_server = GameServer.new()
	_server.name = "GameServer"
	add_child(_server)

	_client = GameClient.new()
	_client.name = "GameClient"
	add_child(_client)

	print("[NetworkManager] Joining %s:%d" % [address, port])
	return OK


func disconnect_game() -> void:
	if _server:
		_server.queue_free()
		_server = null
	if _client:
		_client.queue_free()
		_client = null

	if peer:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = null
	is_host = false
	_peer_to_player.clear()

	# Disconnect all signals
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

	print("[NetworkManager] Disconnected")


func get_player_index(peer_id: int) -> int:
	return _peer_to_player.get(peer_id, -1)


func get_peer_id_for_player(player_index: int) -> int:
	for pid in _peer_to_player:
		if _peer_to_player[pid] == player_index:
			return pid
	return -1


func get_server() -> GameServer:
	return _server


func get_client() -> GameClient:
	return _client


# =============================================================================
# Internal callbacks
# =============================================================================

func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Peer connected: %d" % peer_id)
	_peer_to_player[peer_id] = 1  # Guest is player 1
	player_connected.emit(peer_id)

	# 2 players ready (host + 1 guest)
	if _peer_to_player.size() == 2:
		game_ready.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Peer disconnected: %d" % peer_id)
	_peer_to_player.erase(peer_id)
	player_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	print("[NetworkManager] Connected to server")
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	print("[NetworkManager] Connection failed")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected")
	player_disconnected.emit(1)

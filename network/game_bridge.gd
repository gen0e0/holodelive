class_name GameBridge
extends Node

## サーバー↔クライアント間の通信ブリッジ。
## 全ピアで同一パス (GameRoom/GameBridge) に存在する。
## ローカルモードでは RPC を使わずシグナルで直接配信。
## ネットワークモードでは @rpc メソッドで配信。

## クライアント側シグナル: サーバーから受信したデータを通知
## ローカル: client_state は ClientState オブジェクト
## ネットワーク: client_state は Dictionary（RPC 経由）
signal state_received(player: int, client_state: Variant, events: Array)
signal actions_received(player: int, actions: Array)
signal choice_requested(player: int, choice_data: Dictionary)
signal game_started_received()
signal game_over_received(winner: int)

## ローカルモード: true = RPC 不使用、直接配信
var is_local: bool = true

var _server_context: Node  # ServerContext (親の GameRoom から設定)


# ===========================================================================
# クライアント → サーバー
# ===========================================================================

## クライアントからアクションを送信する。
func send_action(action: Dictionary, player: int) -> void:
	if is_local:
		_deliver_action(action, player)
	else:
		_server_receive_action.rpc_id(1, action)


## クライアントからチョイスを送信する。
func send_choice(choice_idx: int, value: Variant, player: int) -> void:
	if is_local:
		_deliver_choice(choice_idx, value, player)
	else:
		_server_receive_choice.rpc_id(1, choice_idx, value)


@rpc("any_peer", "reliable")
func _server_receive_action(action: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var nm: Node = get_node("/root/NetworkManager")
	var player: int = nm.get_player_index(sender_id) if nm.has_method("get_player_index") else 0
	_deliver_action(action, player)


@rpc("any_peer", "reliable")
func _server_receive_choice(choice_idx: int, value: Variant) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var nm: Node = get_node("/root/NetworkManager")
	var player: int = nm.get_player_index(sender_id) if nm.has_method("get_player_index") else 0
	_deliver_choice(choice_idx, value, player)


func _deliver_action(action: Dictionary, player: int) -> void:
	if _server_context and _server_context.has_method("receive_action"):
		_server_context.receive_action(action, player)


func _deliver_choice(choice_idx: int, value: Variant, player: int) -> void:
	if _server_context and _server_context.has_method("receive_choice"):
		_server_context.receive_choice(choice_idx, value, player)


# ===========================================================================
# サーバー → クライアント（ServerContext から呼ばれる）
# ===========================================================================

## 指定プレイヤーに状態更新を送信。
## ローカル: client_state は ClientState をそのまま渡す。
## ネットワーク: client_state.to_dict() を RPC で送信する。
func send_state_to(player: int, client_state: Variant, events: Array) -> void:
	if is_local:
		state_received.emit(player, client_state, events)
	else:
		var cs_dict: Dictionary = client_state.to_dict() if client_state != null else {}
		var nm: Node = get_node("/root/NetworkManager")
		var peer_id: int = nm.get_peer_id_for_player(player) if nm.has_method("get_peer_id_for_player") else 1
		_client_receive_state.rpc_id(peer_id, player, cs_dict, events)


## 指定プレイヤーにアクション選択肢を送信。
func send_actions_to(player: int, actions: Array) -> void:
	if is_local:
		actions_received.emit(player, actions)
	else:
		var nm: Node = get_node("/root/NetworkManager")
		var peer_id: int = nm.get_peer_id_for_player(player) if nm.has_method("get_peer_id_for_player") else 1
		_client_receive_actions.rpc_id(peer_id, player, actions)


## 指定プレイヤーにチョイス要求を送信。
func send_choice_to(player: int, choice_data: Dictionary) -> void:
	if is_local:
		choice_requested.emit(player, choice_data)
	else:
		var nm: Node = get_node("/root/NetworkManager")
		var peer_id: int = nm.get_peer_id_for_player(player) if nm.has_method("get_peer_id_for_player") else 1
		_client_receive_choice.rpc_id(peer_id, player, choice_data)


## 全クライアントにゲーム開始を通知。
func broadcast_game_started() -> void:
	if is_local:
		game_started_received.emit()
	else:
		_client_receive_game_started.rpc()


## 全クライアントにゲーム終了を通知。
func broadcast_game_over(winner: int) -> void:
	if is_local:
		game_over_received.emit(winner)
	else:
		_client_receive_game_over.rpc(winner)


# ===========================================================================
# クライアント側 @rpc メソッド
# ===========================================================================

@rpc("authority", "reliable", "call_local")
func _client_receive_state(player: int, cs_dict: Dictionary, events: Array) -> void:
	state_received.emit(player, cs_dict, events)


@rpc("authority", "reliable", "call_local")
func _client_receive_actions(player: int, actions: Array) -> void:
	# ActionType 復元
	for a in actions:
		if a.has("type"):
			a["type"] = a["type"] as Enums.ActionType
	actions_received.emit(player, actions)


@rpc("authority", "reliable", "call_local")
func _client_receive_choice(player: int, choice_data: Dictionary) -> void:
	choice_requested.emit(player, choice_data)


@rpc("authority", "reliable", "call_local")
func _client_receive_game_started() -> void:
	game_started_received.emit()


@rpc("authority", "reliable", "call_local")
func _client_receive_game_over(winner: int) -> void:
	game_over_received.emit(winner)

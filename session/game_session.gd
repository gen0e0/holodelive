class_name GameSession
extends RefCounted

signal state_updated(client_state: ClientState, events: Array)
signal actions_received(actions: Array)
signal choice_requested(choice_data: Dictionary)
signal game_started()
signal game_over(winner: int)


func send_action(action: Dictionary) -> void:
	pass


func send_choice(choice_idx: int, value: Variant) -> void:
	pass


func get_client_state() -> ClientState:
	return null


func get_available_actions() -> Array:
	return []


func is_my_turn() -> bool:
	return false


func start_game() -> void:
	pass


## state_updated に伴う後続シグナル（actions_received / choice_requested）を発火する。
## StagingDirector のアニメーション完了後に呼ぶことで、正しい順序を保証する。
## デフォルト実装は何もしない（NetworkGameSession 等は自然なタイミングで発火するため）。
func flush_pending_interaction() -> void:
	pass

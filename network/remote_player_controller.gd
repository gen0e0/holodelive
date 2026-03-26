class_name RemotePlayerController
extends PlayerController

## リモートクライアントからの入力を受け取る PlayerController。
## GameBridge 経由でアクション/チョイスが届いたら decided シグナルを発火。
## サーバー側でリモートプレイヤーを表現するために使う。


## GameBridge から呼ばれる: リモートクライアントがアクションを送信した。
func receive_action(action: Dictionary) -> void:
	action_decided.emit(action)


## GameBridge から呼ばれる: リモートクライアントがチョイスを送信した。
func receive_choice(choice_idx: int, value: Variant) -> void:
	choice_decided.emit(choice_idx, value)

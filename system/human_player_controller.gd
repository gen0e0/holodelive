class_name HumanPlayerController
extends PlayerController

## 人間操作用の PlayerController。
## request_action/choice を受けると UI 通知シグナルを発火し、
## UIからの submit_action/choice 呼び出しで決定シグナルを返す。

## UI に「アクション選択を表示してください」と通知するシグナル。
signal actions_presented(actions: Array)

## UI に「チョイス選択を表示してください」と通知するシグナル。
signal choice_presented(choice_data: Dictionary)


func request_action(actions: Array) -> void:
	actions_presented.emit(actions)


func request_choice(choice_data: Dictionary) -> void:
	choice_presented.emit(choice_data)


## UI（GameScreen 等）から呼ばれる。人間がアクションを選択した時。
func submit_action(action: Dictionary) -> void:
	action_decided.emit(action)


## UI（GameScreen 等）から呼ばれる。人間がチョイスを選択した時。
func submit_choice(choice_idx: int, value: Variant) -> void:
	choice_decided.emit(choice_idx, value)

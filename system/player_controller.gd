class_name PlayerController
extends RefCounted

## プレイヤーの操作主体を抽象化する基底クラス。
## 人間・CPU・デバッグ自動操作は、このクラスのサブクラスとして実装する。
## ServerContext は操作主体の種別を一切知らず、常にこのインターフェースを通じて
## アクション/チョイスを要求し、結果をシグナルで受け取る。

## プレイヤーがアクションを決定した時に発火する。
signal action_decided(action: Dictionary)

## プレイヤーがチョイスを決定した時に発火する。
signal choice_decided(choice_idx: int, value: Variant)


## アクション選択を要求する。利用可能なアクションの一覧を渡す。
## サブクラスは内部で判断し、action_decided を発火する。
func request_action(actions: Array) -> void:
	pass


## チョイス選択を要求する（スキル解決中のカード/ゾーン選択など）。
## サブクラスは内部で判断し、choice_decided を発火する。
func request_choice(choice_data: Dictionary) -> void:
	pass


## 進行中の要求をキャンセルする。
## タイマー待ちやUI操作待ちを中断する場合に呼ぶ。
func cancel() -> void:
	pass

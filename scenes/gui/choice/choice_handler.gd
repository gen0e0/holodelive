class_name ChoiceHandler
extends RefCounted

## 選択UIの基底クラス。
## 各サブクラスは特定の ChoiceType に対応する選択UIを実装する。

signal resolved(choice_idx: int, value: Variant)


func can_handle(_choice_data: Dictionary) -> bool:
	return false


func activate(_choice_data: Dictionary) -> void:
	pass


func deactivate() -> void:
	pass

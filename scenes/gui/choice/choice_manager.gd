class_name ChoiceManager
extends RefCounted

## 複数の ChoiceHandler を管理し、choice_data に応じて適切なハンドラに委譲する。

signal choice_resolved(choice_idx: int, value: Variant)

var _handlers: Array = []  # Array[ChoiceHandler]
var _active_handler: ChoiceHandler = null


func register(handler: ChoiceHandler) -> void:
	_handlers.append(handler)
	handler.resolved.connect(_on_handler_resolved)


func handle_choice(choice_data: Dictionary) -> void:
	cancel()
	for handler in _handlers:
		if handler.can_handle(choice_data):
			_active_handler = handler
			handler.activate(choice_data)
			return


func cancel() -> void:
	if _active_handler != null:
		_active_handler.deactivate()
		_active_handler = null


func is_active() -> bool:
	return _active_handler != null


func _on_handler_resolved(choice_idx: int, value: Variant) -> void:
	# deactivate してから resolved を通知する
	var handler: ChoiceHandler = _active_handler
	_active_handler = null
	if handler != null:
		handler.deactivate()
	choice_resolved.emit(choice_idx, value)

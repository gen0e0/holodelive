class_name ChoiceManager
extends RefCounted

## 複数の ChoiceHandler を管理し、choice_data に応じて適切なハンドラに委譲する。

signal choice_resolved(choice_idx: int, value: Variant)

var _handlers: Array = []  # Array[ChoiceHandler]
var _active_handler: ChoiceHandler = null
var _has_queued_response: bool = false
var _queued_response: Variant  # 次の choice を自動応答する値


func register(handler: ChoiceHandler) -> void:
	_handlers.append(handler)
	handler.resolved.connect(_on_handler_resolved)


func queue_response(value: Variant) -> void:
	_has_queued_response = true
	_queued_response = value
	GameLog.log_event("CHOICE", "queue_response", {"value": value})


func handle_choice(choice_data: Dictionary) -> void:
	cancel()
	# キューされた自動応答があればハンドラを介さず即発火
	if _has_queued_response:
		var value: Variant = _queued_response
		_has_queued_response = false
		var idx: int = choice_data.get("choice_index", 0)
		GameLog.log_event("CHOICE", "auto_respond", {"idx": idx, "value": value})
		choice_resolved.emit(idx, value)
		return
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

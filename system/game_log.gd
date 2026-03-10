extends Node

## 構造化ログシステム。
## ゲーム開始からの相対時刻付きで、AIが解析しやすいフォーマットで標準出力に出力する。
## class_name により、どのクラスからも GameLog.log_event() で呼び出し可能。
##
## フォーマット: [MM:SS.mmm] [CATEGORY] message key=value key=value
## カテゴリ: EVENT, ANIM, CHOICE, ACTION, UI, SKILL

static var _start_time_msec: int = 0
static var _enabled: bool = true


static func reset() -> void:
	_start_time_msec = Time.get_ticks_msec()


static func set_enabled(enabled: bool) -> void:
	_enabled = enabled


static func log_event(category: String, message: String, data: Dictionary = {}) -> void:
	if not _enabled:
		return
	var elapsed: int = Time.get_ticks_msec() - _start_time_msec
	var minutes: int = (elapsed / 1000) / 60
	var seconds: int = (elapsed / 1000) % 60
	var millis: int = elapsed % 1000
	var timestamp: String = "%02d:%02d.%03d" % [minutes, seconds, millis]

	var kv: String = ""
	for key in data:
		var val: Variant = data[key]
		kv += " %s=%s" % [key, _format_value(val)]

	print("[%s] [%-7s] %s%s" % [timestamp, category, message, kv])


static func _format_value(val: Variant) -> String:
	if val is Array:
		var parts: Array[String] = []
		for v in val:
			parts.append(str(v))
		return "[%s]" % ",".join(parts)
	return str(val)

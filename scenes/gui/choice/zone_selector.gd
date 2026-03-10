class_name ZoneSelector
extends ChoiceHandler

## ゾーン選択UI（SELECT_ZONE 用）。
## ステージ / 楽屋などの選択肢をボタンで表示する。

var _ui_parent: Control
var _buttons: Array = []
var _choice_index: int = 0
var _active: bool = false

const _ZONE_LABELS: Dictionary = {
	"stage": "ステージ",
	"backstage": "楽屋",
}


func _init(ui_parent: Control) -> void:
	_ui_parent = ui_parent


func can_handle(choice_data: Dictionary) -> bool:
	return choice_data.get("choice_type", -1) == Enums.ChoiceType.SELECT_ZONE


func activate(choice_data: Dictionary) -> void:
	_choice_index = choice_data.get("choice_index", 0)
	var targets: Array = choice_data.get("valid_targets", [])
	_active = true

	var x: float = 320.0
	for zone in targets:
		var label: String = _ZONE_LABELS.get(zone, str(zone))
		var btn: OverlayButton = OverlayButton.create(label, Rect2(x, 430, 200, 60))
		btn.pressed.connect(_on_zone_pressed.bind(zone))
		_ui_parent.add_child(btn)
		_buttons.append(btn)
		x += 220.0


func deactivate() -> void:
	if not _active:
		return
	_active = false
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()


func _on_zone_pressed(zone: String) -> void:
	if not _active:
		return
	resolved.emit(_choice_index, zone)

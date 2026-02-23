extends Control

## CardView 単体テスト用シーン。
## 左ペインでカードIDを指定し、右ペインにプレビュー表示する。

var _registry: CardRegistry
var _id_input: LineEdit
var _btn_update: Button
var _btn_flip: Button
var _card_view: CardView
var _info_label: RichTextLabel
var _zoom_container: Control
var _face_up: bool = true
var _zoom: float = 1.0
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO  # 中央からのオフセット
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 0.15


func _ready() -> void:
	var loaded: Dictionary = CardLoader.load_all()
	_registry = loaded["card_registry"]
	_build_ui()
	_show_card(1)


func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var hsplit := HSplitContainer.new()
	hsplit.split_offset = 200
	margin.add_child(hsplit)

	# --- 左ペイン ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 180
	hsplit.add_child(left)

	var title := Label.new()
	title.text = "Card Preview"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)

	left.add_child(HSeparator.new())

	var id_row := HBoxContainer.new()
	left.add_child(id_row)

	var id_label := Label.new()
	id_label.text = "Card ID:"
	id_row.add_child(id_label)

	_id_input = LineEdit.new()
	_id_input.text = "1"
	_id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_input.custom_minimum_size.x = 60
	_id_input.text_submitted.connect(_on_text_submitted)
	id_row.add_child(_id_input)

	_btn_update = Button.new()
	_btn_update.text = "Update"
	_btn_update.pressed.connect(_on_update_pressed)
	left.add_child(_btn_update)

	_btn_flip = Button.new()
	_btn_flip.text = "Flip"
	_btn_flip.pressed.connect(_on_flip_pressed)
	left.add_child(_btn_flip)

	left.add_child(HSeparator.new())

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.selection_enabled = true
	_info_label.focus_mode = Control.FOCUS_NONE
	left.add_child(_info_label)

	# --- 右ペイン ---
	_zoom_container = Control.new()
	_zoom_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_zoom_container.clip_contents = true
	_zoom_container.gui_input.connect(_on_zoom_input)
	_zoom_container.resized.connect(_center_card)
	hsplit.add_child(_zoom_container)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.16)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_container.add_child(bg)

	var scene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
	_card_view = scene.instantiate()
	_card_view.managed_hover = true
	_card_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_zoom_container.add_child(_card_view)


func _show_card(card_id: int) -> void:
	var card_def: CardDef = _registry.get_card(card_id)
	if card_def == null:
		_info_label.clear()
		_info_label.append_text("[color=red]Card ID %d not found[/color]" % card_id)
		_card_view.setup({}, true)
		return

	var card_data: Dictionary = {
		"instance_id": card_id,
		"card_id": card_def.card_id,
		"nickname": card_def.nickname,
		"icons": card_def.base_icons,
		"suits": card_def.base_suits,
		"image_path": card_def.dir_path + "/img_card.png",
	}
	_card_view.setup(card_data, _face_up)

	# 情報表示
	_info_label.clear()
	var lines: Array[String] = []
	lines.append("[b]#%03d %s[/b]" % [card_def.card_id, card_def.nickname])
	lines.append("Icons: %s" % ", ".join(card_def.base_icons))
	lines.append("Suits: %s" % ", ".join(card_def.base_suits))
	lines.append("")
	for skill in card_def.skills:
		var type_name: String = "play" if skill["type"] == Enums.SkillType.PLAY else ("action" if skill["type"] == Enums.SkillType.ACTION else "passive")
		lines.append("[color=yellow][%s][/color] %s" % [type_name, skill["name"]])
		lines.append("  %s" % skill["description"])
	_info_label.append_text("\n".join(lines))
	_drag_offset = Vector2.ZERO
	_center_card()


func _on_update_pressed() -> void:
	var text: String = _id_input.text.strip_edges()
	if not text.is_valid_int():
		_info_label.clear()
		_info_label.append_text("[color=red]Invalid ID[/color]")
		return
	_show_card(text.to_int())


func _on_flip_pressed() -> void:
	_face_up = not _face_up
	_on_update_pressed()


func _on_text_submitted(_text: String) -> void:
	_on_update_pressed()


func _on_zoom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			_apply_zoom()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			_apply_zoom()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start_mouse = mb.global_position
				_drag_start_offset = _drag_offset
			else:
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			_drag_offset = Vector2.ZERO
			_apply_zoom()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_drag_offset = _drag_start_offset + (mm.global_position - _drag_start_mouse)
		_apply_zoom()


func _apply_zoom() -> void:
	_card_view.scale = Vector2(_zoom, _zoom)
	_center_card()


func _center_card() -> void:
	if _card_view == null or _zoom_container == null:
		return
	var container_size: Vector2 = _zoom_container.size
	var card_size: Vector2 = _card_view.size * _zoom
	_card_view.position = (container_size - card_size) / 2.0 + _drag_offset

extends Control

## ChibiCharacter プレビューシーン。
## JSON パスを指定してロードし、表情切替・ボーン回転を確認する。

const DEFAULT_JSON: String = "res://artwork/chibi/000_sample.json"
const BONE_LIST: Array[String] = [
	"右肩", "右肘", "右手首",
	"左肩", "左肘", "左手首",
	"右股関節", "右膝", "右足首",
	"左股関節", "左膝", "左足首",
	"首の付け根",
]

var _path_input: LineEdit
var _btn_load: Button
var _expression_options: OptionButton
var _bone_options: OptionButton
var _rotation_slider: HSlider
var _rotation_label: Label
var _info_label: RichTextLabel
var _zoom_container: Control
var _character_container: Node2D
var _chibi: ChibiCharacter
var _zoom: float = 2.0
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO

const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 8.0
const ZOOM_STEP: float = 0.25


func _ready() -> void:
	_build_ui()
	_load_path(DEFAULT_JSON)


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
	hsplit.split_offset = 260
	margin.add_child(hsplit)

	# --- 左ペイン ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 240
	hsplit.add_child(left)

	var title := Label.new()
	title.text = "Chibiキャラクター プレビュー"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)

	left.add_child(HSeparator.new())

	var path_label := Label.new()
	path_label.text = "JSONパス:"
	left.add_child(path_label)

	_path_input = LineEdit.new()
	_path_input.text = DEFAULT_JSON
	_path_input.text_submitted.connect(_on_path_submitted)
	left.add_child(_path_input)

	_btn_load = Button.new()
	_btn_load.text = "読み込み"
	_btn_load.pressed.connect(_on_load_pressed)
	left.add_child(_btn_load)

	left.add_child(HSeparator.new())

	# 表情
	var expr_label := Label.new()
	expr_label.text = "表情:"
	left.add_child(expr_label)

	_expression_options = OptionButton.new()
	_expression_options.item_selected.connect(_on_expression_selected)
	left.add_child(_expression_options)

	# 目・口ボタン
	var eye_row := HBoxContainer.new()
	left.add_child(eye_row)
	var eye_label := Label.new()
	eye_label.text = "目:"
	eye_label.custom_minimum_size.x = 40
	eye_row.add_child(eye_label)
	var btn_eye_open := Button.new()
	btn_eye_open.text = "開"
	btn_eye_open.pressed.connect(func() -> void: _chibi.set_eye_state("opened"))
	eye_row.add_child(btn_eye_open)
	var btn_eye_close := Button.new()
	btn_eye_close.text = "閉"
	btn_eye_close.pressed.connect(func() -> void: _chibi.set_eye_state("closed"))
	eye_row.add_child(btn_eye_close)

	var mouth_row := HBoxContainer.new()
	left.add_child(mouth_row)
	var mouth_label := Label.new()
	mouth_label.text = "口:"
	mouth_label.custom_minimum_size.x = 40
	mouth_row.add_child(mouth_label)
	var btn_mouth_close := Button.new()
	btn_mouth_close.text = "閉"
	btn_mouth_close.pressed.connect(func() -> void: _chibi.set_mouth_state("closed"))
	mouth_row.add_child(btn_mouth_close)
	var btn_mouth_open := Button.new()
	btn_mouth_open.text = "開"
	btn_mouth_open.pressed.connect(func() -> void: _chibi.set_mouth_state("opened"))
	mouth_row.add_child(btn_mouth_open)

	left.add_child(HSeparator.new())

	# ボーン回転
	var bone_title := Label.new()
	bone_title.text = "ボーン回転:"
	left.add_child(bone_title)

	_bone_options = OptionButton.new()
	for b: String in BONE_LIST:
		_bone_options.add_item(b)
	_bone_options.item_selected.connect(_on_bone_selected)
	left.add_child(_bone_options)

	_rotation_label = Label.new()
	_rotation_label.text = "0°"
	left.add_child(_rotation_label)

	_rotation_slider = HSlider.new()
	_rotation_slider.min_value = -180
	_rotation_slider.max_value = 180
	_rotation_slider.step = 1
	_rotation_slider.value = 0
	_rotation_slider.value_changed.connect(_on_rotation_changed)
	left.add_child(_rotation_slider)

	var btn_reset := Button.new()
	btn_reset.text = "ポーズリセット"
	btn_reset.pressed.connect(_on_reset_pose)
	left.add_child(btn_reset)

	left.add_child(HSeparator.new())

	# 情報
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
	_zoom_container.resized.connect(_center_character)
	hsplit.add_child(_zoom_container)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.16)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_container.add_child(bg)

	var sub_viewport_container := SubViewportContainer.new()
	sub_viewport_container.anchor_right = 1.0
	sub_viewport_container.anchor_bottom = 1.0
	sub_viewport_container.stretch = true
	sub_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_container.add_child(sub_viewport_container)

	var sub_viewport := SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport_container.add_child(sub_viewport)

	_character_container = Node2D.new()
	_character_container.name = "CharacterContainer"
	sub_viewport.add_child(_character_container)

	var scene: PackedScene = preload("res://scenes/gui/components/chibi_character.tscn")
	_chibi = scene.instantiate()
	_character_container.add_child(_chibi)


func _load_path(path: String) -> void:
	var ok: bool = _chibi.load_from_json(path)
	_info_label.clear()
	if not ok:
		_info_label.append_text("[color=red]読み込み失敗: %s[/color]" % path)
		return

	_expression_options.clear()
	var expressions: Array[String] = _chibi.get_available_expressions()
	for i in range(expressions.size()):
		_expression_options.add_item(expressions[i], i)
	var normal_idx: int = expressions.find("normal")
	if normal_idx >= 0:
		_expression_options.select(normal_idx)

	var lines: Array[String] = []
	lines.append("[b]Chibi: %s[/b]" % path.get_file())
	lines.append("表情: %s" % ", ".join(expressions))
	lines.append("ボーン: %d" % BONE_LIST.size())
	_info_label.append_text("\n".join(lines))

	_drag_offset = Vector2.ZERO
	_center_character()
	_on_bone_selected(0)


func _on_path_submitted(_text: String) -> void:
	_on_load_pressed()


func _on_load_pressed() -> void:
	_load_path(_path_input.text.strip_edges())


func _on_expression_selected(index: int) -> void:
	_chibi.set_expression(_expression_options.get_item_text(index))


func _on_bone_selected(_index: int) -> void:
	var bone_name: String = _bone_options.get_item_text(_bone_options.selected)
	var bone: Node2D = _chibi.get_bone(bone_name)
	if bone != null:
		_rotation_slider.value = rad_to_deg(bone.rotation)
		_rotation_label.text = "%d°" % int(_rotation_slider.value)


func _on_rotation_changed(value: float) -> void:
	var bone_name: String = _bone_options.get_item_text(_bone_options.selected)
	var bone: Node2D = _chibi.get_bone(bone_name)
	if bone != null:
		bone.rotation = deg_to_rad(value)
		_rotation_label.text = "%d°" % int(value)


func _on_reset_pose() -> void:
	for b: String in ChibiCharacter.BONE_ORDER:
		var bone: Node2D = _chibi.get_bone(b)
		if bone != null:
			bone.rotation = 0.0
	_on_bone_selected(_bone_options.selected)


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
	_character_container.scale = Vector2(_zoom, _zoom)
	_center_character()


func _center_character() -> void:
	if _character_container == null or _zoom_container == null:
		return
	var container_size: Vector2 = _zoom_container.size
	_character_container.position = container_size / 2.0 + _drag_offset

extends Control

## SDCharacter プレビューシーン。
## カードIDを指定してSDキャラクターを表示・表情切り替えを確認する。

var _registry: CardRegistry
var _id_input: LineEdit
var _btn_update: Button
var _btn_idle: Button
var _btn_talk: Button
var _btn_wave: Button
var _expression_options: OptionButton
var _sd_character: SDCharacter
var _info_label: RichTextLabel
var _zoom_container: Control
var _character_container: Node2D
var _zoom: float = 2.0
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 8.0
const ZOOM_STEP: float = 0.25


func _ready() -> void:
	var loaded: Dictionary = CardLoader.load_all()
	_registry = loaded["card_registry"]
	_build_ui()
	_show_character(20)


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
	hsplit.split_offset = 220
	margin.add_child(hsplit)

	# --- 左ペイン ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 200
	hsplit.add_child(left)

	var title := Label.new()
	title.text = "SD Character Preview"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)

	left.add_child(HSeparator.new())

	# Card ID 入力
	var id_row := HBoxContainer.new()
	left.add_child(id_row)

	var id_label := Label.new()
	id_label.text = "Card ID:"
	id_row.add_child(id_label)

	_id_input = LineEdit.new()
	_id_input.text = "20"
	_id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_input.custom_minimum_size.x = 60
	_id_input.text_submitted.connect(_on_text_submitted)
	id_row.add_child(_id_input)

	_btn_update = Button.new()
	_btn_update.text = "Update"
	_btn_update.pressed.connect(_on_update_pressed)
	left.add_child(_btn_update)

	left.add_child(HSeparator.new())

	# 表情切り替え
	var expr_label := Label.new()
	expr_label.text = "Expression:"
	left.add_child(expr_label)

	_expression_options = OptionButton.new()
	_expression_options.item_selected.connect(_on_expression_selected)
	left.add_child(_expression_options)

	left.add_child(HSeparator.new())

	# アニメーション
	_btn_idle = Button.new()
	_btn_idle.text = "Idle"
	_btn_idle.pressed.connect(_on_idle_pressed)
	left.add_child(_btn_idle)

	_btn_talk = Button.new()
	_btn_talk.text = "Talk"
	_btn_talk.pressed.connect(_on_talk_pressed)
	left.add_child(_btn_talk)

	_btn_wave = Button.new()
	_btn_wave.text = "Wave"
	_btn_wave.pressed.connect(_on_wave_pressed)
	left.add_child(_btn_wave)

	left.add_child(HSeparator.new())

	# 情報表示
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

	# SubViewport でNode2DをControl内に表示
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

	var scene: PackedScene = preload("res://scenes/gui/components/sd_character.tscn")
	_sd_character = scene.instantiate()
	_character_container.add_child(_sd_character)


func _show_character(card_id: int) -> void:
	var card_def: CardDef = _registry.get_card(card_id)
	if card_def == null:
		_info_label.clear()
		_info_label.append_text("[color=red]Card ID %d not found[/color]" % card_id)
		return

	_sd_character.setup(card_def.card_id, card_def.dir_path)

	# 表情リスト更新
	_expression_options.clear()
	var expressions: Array[String] = _sd_character.get_available_expressions()
	for i in range(expressions.size()):
		_expression_options.add_item(expressions[i], i)
	# normal があればデフォルト選択
	var normal_idx: int = expressions.find("normal")
	if normal_idx >= 0:
		_expression_options.select(normal_idx)

	# 情報表示
	_info_label.clear()
	var lines: Array[String] = []
	lines.append("[b]#%03d %s[/b]" % [card_def.card_id, card_def.nickname])
	lines.append("Dir: %s" % card_def.dir_path)
	lines.append("")
	lines.append("[color=gray]Expressions: %s[/color]" % ", ".join(expressions))
	_info_label.append_text("\n".join(lines))

	_drag_offset = Vector2.ZERO
	_center_character()

	# デフォルトでIdle開始
	_sd_character.play_idle()
	_btn_idle.text = "Stop"
	_btn_talk.text = "Talk"


func _on_update_pressed() -> void:
	var text: String = _id_input.text.strip_edges()
	if not text.is_valid_int():
		_info_label.clear()
		_info_label.append_text("[color=red]Invalid ID[/color]")
		return
	_show_character(text.to_int())


func _on_text_submitted(_text: String) -> void:
	_on_update_pressed()


func _on_expression_selected(index: int) -> void:
	var expr_name: String = _expression_options.get_item_text(index)
	_sd_character.set_expression(expr_name)


func _on_idle_pressed() -> void:
	_sd_character.stop_animation()
	_btn_talk.text = "Talk"
	if _btn_idle.text == "Idle":
		_sd_character.play_idle()
		_btn_idle.text = "Stop"
	else:
		_btn_idle.text = "Idle"


func _on_talk_pressed() -> void:
	_sd_character.stop_animation()
	_btn_idle.text = "Idle"
	if _btn_talk.text == "Talk":
		_sd_character.play_talking()
		_btn_talk.text = "Stop"
	else:
		_btn_talk.text = "Talk"


func _on_wave_pressed() -> void:
	_sd_character.play_emote_wave()
	_btn_idle.text = "Stop"
	_btn_talk.text = "Talk"


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

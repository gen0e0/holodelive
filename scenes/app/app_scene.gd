extends Control

var _btn_single: Button
var _btn_multi: Button
var _btn_settings: Button


func _ready() -> void:
	_build_ui()
	# CLI 引数でマルチプレイヤー自動起動
	var args: Array = OS.get_cmdline_user_args()
	for arg in args:
		var a: String = str(arg)
		if a == "--host" or a.begins_with("--join"):
			call_deferred("_on_multi_pressed")
			return


# =============================================================================
# UI
# =============================================================================

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 400
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "HOLOdeLIVE"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Turn-Based Card Game"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	vbox.add_child(spacer)

	# Single Player button
	_btn_single = Button.new()
	_btn_single.text = "Single Player"
	_btn_single.custom_minimum_size.y = 50
	_btn_single.add_theme_font_size_override("font_size", 20)
	_btn_single.pressed.connect(_on_single_pressed)
	vbox.add_child(_btn_single)

	# Multiplayer button
	_btn_multi = Button.new()
	_btn_multi.text = "Multiplayer"
	_btn_multi.custom_minimum_size.y = 50
	_btn_multi.add_theme_font_size_override("font_size", 20)
	_btn_multi.pressed.connect(_on_multi_pressed)
	vbox.add_child(_btn_multi)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 20
	vbox.add_child(spacer2)

	# Settings button
	_btn_settings = Button.new()
	_btn_settings.text = "設定"
	_btn_settings.custom_minimum_size.y = 50
	_btn_settings.add_theme_font_size_override("font_size", 20)
	_btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(_btn_settings)


# =============================================================================
# Handlers
# =============================================================================

func _on_single_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/debug/debug_scene.tscn")


func _on_multi_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby_scene.tscn")


func _on_settings_pressed() -> void:
	GameConfig.open_settings()

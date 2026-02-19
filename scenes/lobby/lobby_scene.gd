extends Control

var _btn_host: Button
var _btn_join: Button
var _input_ip: LineEdit
var _status_label: Label


func _ready() -> void:
	_build_ui()
	var nm: Node = get_node("/root/NetworkManager")
	nm.game_ready.connect(_on_game_ready)
	nm.connection_succeeded.connect(_on_connection_succeeded)
	nm.connection_failed.connect(_on_connection_failed)


# =============================================================================
# UI
# =============================================================================

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 300
	center.add_child(vbox)

	var title := Label.new()
	title.text = "HOLOdeLIVE"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 16
	vbox.add_child(spacer1)

	_btn_host = Button.new()
	_btn_host.text = "Host Game"
	_btn_host.pressed.connect(_on_host_pressed)
	vbox.add_child(_btn_host)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 8
	vbox.add_child(spacer2)

	var join_row := HBoxContainer.new()
	vbox.add_child(join_row)

	_input_ip = LineEdit.new()
	_input_ip.placeholder_text = "127.0.0.1"
	_input_ip.text = "127.0.0.1"
	_input_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_input_ip)

	_btn_join = Button.new()
	_btn_join.text = "Join Game"
	_btn_join.pressed.connect(_on_join_pressed)
	join_row.add_child(_btn_join)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size.y = 16
	vbox.add_child(spacer3)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)


# =============================================================================
# Handlers
# =============================================================================

func _on_host_pressed() -> void:
	var nm: Node = get_node("/root/NetworkManager")
	var err: Error = nm.host_game()
	if err != OK:
		_status_label.text = "Failed to host: %s" % error_string(err)
		return
	_status_label.text = "Hosting... waiting for opponent."
	_btn_host.disabled = true
	_btn_join.disabled = true


func _on_join_pressed() -> void:
	var nm: Node = get_node("/root/NetworkManager")
	var address: String = _input_ip.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"

	var err: Error = nm.join_game(address)
	if err != OK:
		_status_label.text = "Failed to join: %s" % error_string(err)
		return
	_status_label.text = "Connecting to %s..." % address
	_btn_host.disabled = true
	_btn_join.disabled = true


func _on_game_ready() -> void:
	_status_label.text = "Game ready! Starting..."
	# Small delay so the label is visible
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/game/game_scene.tscn")


func _on_connection_succeeded() -> void:
	_status_label.text = "Connected! Starting..."
	# Guest also transitions to game scene
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/game/game_scene.tscn")


func _on_connection_failed() -> void:
	_status_label.text = "Connection failed."
	_btn_host.disabled = false
	_btn_join.disabled = false

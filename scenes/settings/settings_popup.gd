extends PopupPanel

const LABEL_MIN_WIDTH: float = 120.0
const SLIDER_MIN_WIDTH: float = 300.0
const VALUE_MIN_WIDTH: float = 60.0

var _slider_master: HSlider
var _slider_bgm: HSlider
var _slider_sfx: HSlider
var _label_master_val: Label
var _label_bgm_val: Label
var _label_sfx_val: Label


func _ready() -> void:
	_build_ui()
	_sync_from_config()
	popup_window = true


# =============================================================================
# UI 構築
# =============================================================================

func _build_ui() -> void:
	# パネル背景: 濃いグレー・不透明・角丸5px
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	panel_style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# タイトル行
	var title_row := HBoxContainer.new()
	root.add_child(title_row)

	var title := Label.new()
	title.text = "設定"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var btn_close := Button.new()
	btn_close.text = "\u2715"
	btn_close.custom_minimum_size = Vector2(32, 32)
	btn_close.add_theme_font_size_override("font_size", 20)
	btn_close.add_theme_color_override("font_color", Color.WHITE)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.25, 0.28)
	btn_style.set_corner_radius_all(4)
	btn_close.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.4, 0.2, 0.2)
	btn_hover.set_corner_radius_all(4)
	btn_close.add_theme_stylebox_override("hover", btn_hover)
	btn_close.pressed.connect(_on_close_pressed)
	title_row.add_child(btn_close)

	root.add_child(HSeparator.new())

	# オーディオセクション
	var audio_label := Label.new()
	audio_label.text = "オーディオ"
	audio_label.add_theme_font_size_override("font_size", 20)
	audio_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(audio_label)

	var audio_box := VBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 8)
	root.add_child(audio_box)

	_slider_master = _create_volume_row(audio_box, "マスター")
	_label_master_val = _get_value_label(_slider_master)
	_slider_master.value_changed.connect(_on_master_changed)

	_slider_bgm = _create_volume_row(audio_box, "BGM")
	_label_bgm_val = _get_value_label(_slider_bgm)
	_slider_bgm.value_changed.connect(_on_bgm_changed)

	_slider_sfx = _create_volume_row(audio_box, "SFX")
	_label_sfx_val = _get_value_label(_slider_sfx)
	_slider_sfx.value_changed.connect(_on_sfx_changed)

	# ポップアップ非表示時に保存
	visibility_changed.connect(_on_visibility_changed)


func _create_volume_row(parent: VBoxContainer, label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = LABEL_MIN_WIDTH
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.x = SLIDER_MIN_WIDTH
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_label := Label.new()
	val_label.custom_minimum_size.x = VALUE_MIN_WIDTH
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 16)
	val_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(val_label)

	return slider


func _get_value_label(slider: HSlider) -> Label:
	return slider.get_parent().get_child(2) as Label


# =============================================================================
# 同期
# =============================================================================

func _sync_from_config() -> void:
	_slider_master.set_value_no_signal(GameConfig.master_volume)
	_slider_bgm.set_value_no_signal(GameConfig.bgm_volume)
	_slider_sfx.set_value_no_signal(GameConfig.sfx_volume)
	_update_value_label(_label_master_val, GameConfig.master_volume)
	_update_value_label(_label_bgm_val, GameConfig.bgm_volume)
	_update_value_label(_label_sfx_val, GameConfig.sfx_volume)


func _update_value_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(value * 100)


# =============================================================================
# ハンドラ
# =============================================================================

func _on_master_changed(value: float) -> void:
	GameConfig.master_volume = value
	_update_value_label(_label_master_val, value)


func _on_bgm_changed(value: float) -> void:
	GameConfig.bgm_volume = value
	_update_value_label(_label_bgm_val, value)


func _on_sfx_changed(value: float) -> void:
	GameConfig.sfx_volume = value
	_update_value_label(_label_sfx_val, value)


func _on_close_pressed() -> void:
	hide()


func _on_visibility_changed() -> void:
	if not visible:
		GameConfig.save_settings()

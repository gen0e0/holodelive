class_name CardTooltip
extends Control

## カードホバー時に詳細情報を表示するポップアップ。
## GameScreen の Content (1920x1080) 直下に配置し、show_tooltip / hide_tooltip で制御する。

const ICON_VIEW_SCENE: PackedScene = preload("res://scenes/gui/components/icon_view.tscn")
const DESIGN_W: float = 1920.0
const DESIGN_H: float = 1080.0
const MARGIN: float = 16.0

const SKILL_TYPE_LABELS: Dictionary = {
	Enums.SkillType.PLAY: "Play",
	Enums.SkillType.ACTION: "Action",
	Enums.SkillType.PASSIVE: "Passive",
}

var _panel: PanelContainer
var _name_label: Label
var _icon_container: HBoxContainer
var _suit_label: Label
var _skills_container: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_panel.visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_color = Color(0.5, 0.5, 0.6, 0.8)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Name
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(_name_label)

	# Icons
	_icon_container = HBoxContainer.new()
	_icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_icon_container)

	# Suit
	_suit_label = Label.new()
	_suit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suit_label.add_theme_font_size_override("font_size", 16)
	_suit_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
	vbox.add_child(_suit_label)

	# Separator
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# Skills container
	_skills_container = VBoxContainer.new()
	_skills_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skills_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_skills_container)


func show_tooltip(card_data: Dictionary, card_rect: Rect2) -> void:
	# Populate content
	var card_id: int = card_data.get("card_id", 0)
	var nickname: String = card_data.get("nickname", "?")
	_name_label.text = "#%03d %s" % [card_id, nickname]

	# Icons
	for child in _icon_container.get_children():
		child.queue_free()
	var icons: Array = card_data.get("icons", [])
	for ic in icons:
		var iv: IconView = ICON_VIEW_SCENE.instantiate()
		iv.icon_name = str(ic)
		_icon_container.add_child(iv)

	# Suits
	var suits: Array = card_data.get("suits", [])
	_suit_label.text = ", ".join(suits)

	# Skills
	for child in _skills_container.get_children():
		child.queue_free()
	var skills: Array = card_data.get("skills", [])
	for skill in skills:
		var skill_name: String = skill.get("name", "")
		var skill_type: int = skill.get("type", Enums.SkillType.PLAY)
		var skill_desc: String = skill.get("description", "")
		var type_label: String = SKILL_TYPE_LABELS.get(skill_type, "?")

		var header := Label.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
		header.text = "[%s] %s" % [type_label, skill_name]
		_skills_container.add_child(header)

		if skill_desc != "":
			var desc := Label.new()
			desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc.add_theme_font_size_override("font_size", 14)
			desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size.x = 250
			_skills_container.add_child(desc)
			desc.text = skill_desc

	_panel.visible = true
	# Wait one frame for layout to resolve, then position
	await get_tree().process_frame
	_position_panel(card_rect)


func hide_tooltip() -> void:
	_panel.visible = false


func _position_panel(card_rect: Rect2) -> void:
	var panel_size: Vector2 = _panel.size

	# Try right placement
	var px: float = card_rect.end.x + MARGIN
	if px + panel_size.x > DESIGN_W:
		# Fall back to left
		px = card_rect.position.x - MARGIN - panel_size.x

	# Y: align to card top, clamp to screen
	var py: float = card_rect.position.y
	if py + panel_size.y > DESIGN_H:
		py = DESIGN_H - panel_size.y
	if py < 0:
		py = 0

	_panel.position = Vector2(px, py)

class_name RankLabel
extends Panel

## ステージ役名ラベル。ステージ+楽屋のオープン済みカードからランクを算出して表示する。

const LABEL_SIZE := Vector2(280, 32)
const CORNER_RADIUS: int = 6
const FONT_SIZE: int = 18
const BG_COLOR := Color(0.1, 0.1, 0.15, 0.8)

const RANK_COLORS: Dictionary = {
	Enums.ShowdownRank.MIRACLE: Color(1.0, 0.85, 0.2),
	Enums.ShowdownRank.TRIO: Color(0.8, 0.5, 1.0),
	Enums.ShowdownRank.FLASH: Color(0.4, 0.7, 1.0),
	Enums.ShowdownRank.DUO: Color(0.5, 0.9, 0.5),
	Enums.ShowdownRank.CASUAL: Color(0.6, 0.6, 0.6),
}

var _label: Label
var _current_rank: Enums.ShowdownRank = Enums.ShowdownRank.CASUAL


func _ready() -> void:
	custom_minimum_size = LABEL_SIZE
	size = LABEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.text = "-"
	_label.add_theme_color_override("font_color", RANK_COLORS[Enums.ShowdownRank.CASUAL])
	add_child(_label)


## ステージ+楽屋のオープン済みカードからランクを算出して表示を更新する。
## 裏向き (hidden / face_down) のカードは除外する。
## 戻り値: 算出した ShowdownRank
func update_rank(stage_cards: Array, backstage_card: Variant) -> Enums.ShowdownRank:
	var unit: Array = []
	for d in stage_cards:
		var dict: Dictionary = d
		if dict.get("hidden", false) or dict.get("face_down", false):
			continue
		unit.append(dict)
	if backstage_card != null:
		var bs: Dictionary = backstage_card
		if not bs.get("hidden", false) and not bs.get("face_down", false):
			unit.append(bs)

	if unit.is_empty():
		_current_rank = Enums.ShowdownRank.CASUAL
		_label.text = "-"
		_label.add_theme_color_override("font_color", RANK_COLORS[Enums.ShowdownRank.CASUAL])
		return _current_rank

	_current_rank = ShowdownCalculator.evaluate_rank(unit)
	_label.text = DisplayHelper.get_rank_name(_current_rank)
	_label.add_theme_color_override("font_color", RANK_COLORS[_current_rank])
	return _current_rank


## 優劣表示。勝っている側を明るく、負けている側を暗くする。
func set_superior(is_superior: bool) -> void:
	if is_superior:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.6, 0.6, 0.6, 0.8)

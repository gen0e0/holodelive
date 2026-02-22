class_name TopBar
extends HBoxContainer

var _round_label: Label
var _turn_label: Label
var _phase_label: Label
var _wins_label: Label


func _ready() -> void:
	_round_label = _make_label("Round: 1")
	_turn_label = _make_label("Turn: 1")
	_phase_label = _make_label("Phase: ACTION")
	_wins_label = _make_label("Wins: 0 - 0")


func update_display(cs: ClientState) -> void:
	_round_label.text = "Round: %d" % cs.round_number
	_turn_label.text = "Turn: %d" % cs.turn_number
	_phase_label.text = "Phase: %s" % DisplayHelper.get_phase_name(cs.phase)
	_wins_label.text = "Wins: %d - %d" % [cs.round_wins[0], cs.round_wins[1]]


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)
	return lbl

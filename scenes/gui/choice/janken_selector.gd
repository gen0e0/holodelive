class_name JankenSelector
extends ChoiceHandler

## じゃんけんUI: G(グー)/P(パー)/C(チョキ) を選択するモーダルウィンドウ。
## 3ラウンドにわたって持続し、各ラウンドの結果を表示する。
##
## ui_hint 形式: "janken:ROUND:WINS:MY_LAST:OPP_LAST"
##   ROUND: 1-3
##   WINS: スキル発動者の勝利数
##   MY_LAST: 前ラウンドの自分の手 (G/P/C) — ラウンド1では空
##   OPP_LAST: 前ラウンドの相手の手 — ラウンド1では空

const HAND_LABELS: Dictionary = {"G": "✊", "P": "✋", "C": "✌️"}
const HAND_NAMES: Dictionary = {"G": "グー", "P": "パー", "C": "チョキ"}

var _ui_parent: Control
var _choice_index: int = 0
var _active: bool = false

# --- モーダル要素 ---
var _modal_bg: Panel = null
var _modal_panel: Panel = null
var _wins_label: Label = null
var _round_label: Label = null
var _my_hand_label: Label = null
var _vs_label: Label = null
var _opp_hand_label: Label = null
var _result_label: Label = null
var _buttons: Array = []  # OverlayButton[]


func _init(ui_parent: Control) -> void:
	_ui_parent = ui_parent


func can_handle(choice_data: Dictionary) -> bool:
	var hint: String = choice_data.get("ui_hint", "")
	return hint.begins_with("janken:")


func activate(choice_data: Dictionary) -> void:
	_choice_index = choice_data.get("choice_index", 0)
	_active = true

	var hint: String = choice_data.get("ui_hint", "janken:1:0::")
	var parts: PackedStringArray = hint.split(":")
	var round_num: int = parts[1].to_int() if parts.size() > 1 else 1
	var wins: int = parts[2].to_int() if parts.size() > 2 else 0
	var my_last: String = parts[3] if parts.size() > 3 else ""
	var opp_last: String = parts[4] if parts.size() > 4 else ""

	if _modal_bg == null:
		_create_modal()

	_update_wins(wins)
	_round_label.text = "Round %d / 3" % round_num

	if not my_last.is_empty() and not opp_last.is_empty():
		# 前ラウンドの結果を表示してから次のボタンを出す
		_show_result(my_last, opp_last, wins)
		_hide_buttons()
		var tree: SceneTree = _ui_parent.get_tree()
		await tree.create_timer(1.5).timeout
		if not _active:
			return

	_my_hand_label.text = "?"
	_opp_hand_label.text = "?"
	_result_label.text = ""
	_show_buttons()


func deactivate() -> void:
	_active = false
	_hide_buttons()
	# 少し待って次の activate が来なければモーダルを破棄
	if _modal_bg != null and is_instance_valid(_modal_bg):
		var tree: SceneTree = _ui_parent.get_tree()
		if tree != null:
			await tree.create_timer(3.0).timeout
			if not _active and _modal_bg != null:
				destroy_modal()


func destroy_modal() -> void:
	if _modal_bg != null:
		_modal_bg.queue_free()
		_modal_bg = null
	_modal_panel = null
	_wins_label = null
	_round_label = null
	_my_hand_label = null
	_vs_label = null
	_opp_hand_label = null
	_result_label = null
	_buttons.clear()


## 外部から呼ばれる: じゃんけん終了時にモーダルを閉じる
func show_final_result(wins: int, my_last: String, opp_last: String) -> void:
	if _modal_bg == null:
		return
	_update_wins(wins)
	_round_label.text = "結果"
	_show_result(my_last, opp_last, wins)
	_hide_buttons()
	var tree: SceneTree = _ui_parent.get_tree()
	await tree.create_timer(2.0).timeout
	destroy_modal()


# ---------------------------------------------------------------------------
# 結果表示
# ---------------------------------------------------------------------------

func _show_result(my_hand: String, opp_hand: String, _wins: int) -> void:
	_my_hand_label.text = HAND_LABELS.get(my_hand, "?")
	_opp_hand_label.text = HAND_LABELS.get(opp_hand, "?")
	var winner: String = _judge(my_hand, opp_hand)
	match winner:
		"win":
			_result_label.text = "WIN!"
			_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		"lose":
			_result_label.text = "LOSE"
			_result_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		"draw":
			_result_label.text = "DRAW"
			_result_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))


static func _judge(my_hand: String, opp_hand: String) -> String:
	if my_hand == opp_hand:
		return "draw"
	if (my_hand == "G" and opp_hand == "C") or \
	   (my_hand == "P" and opp_hand == "G") or \
	   (my_hand == "C" and opp_hand == "P"):
		return "win"
	return "lose"


# ---------------------------------------------------------------------------
# ボタン操作
# ---------------------------------------------------------------------------

func _on_button_pressed(hand: String) -> void:
	if not _active:
		return
	_active = false
	_my_hand_label.text = HAND_LABELS.get(hand, "?")
	_opp_hand_label.text = "?"
	_result_label.text = ""
	_hide_buttons()
	resolved.emit(_choice_index, hand)


func _show_buttons() -> void:
	for btn in _buttons:
		btn.visible = true


func _hide_buttons() -> void:
	for btn in _buttons:
		btn.visible = false


# ---------------------------------------------------------------------------
# UI生成
# ---------------------------------------------------------------------------

func _update_wins(wins: int) -> void:
	if _wins_label != null:
		_wins_label.text = "WINS: %d" % wins


func _create_modal() -> void:
	# 半透明背景
	_modal_bg = Panel.new()
	_modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_bg.z_index = 200
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.6)
	_modal_bg.add_theme_stylebox_override("panel", bg_style)
	_modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_parent.add_child(_modal_bg)

	# モーダルパネル
	_modal_panel = Panel.new()
	_modal_panel.position = Vector2(460, 200)
	_modal_panel.size = Vector2(1000, 600)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	panel_style.border_color = Color(0.4, 0.5, 0.8, 0.8)
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	_modal_panel.add_theme_stylebox_override("panel", panel_style)
	_modal_bg.add_child(_modal_panel)

	# WINS ラベル
	_wins_label = Label.new()
	_wins_label.text = "WINS: 0"
	_wins_label.position = Vector2(0, 30)
	_wins_label.size = Vector2(1000, 50)
	_wins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wins_label.add_theme_font_size_override("font_size", 36)
	_wins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_modal_panel.add_child(_wins_label)

	# Round ラベル
	_round_label = Label.new()
	_round_label.text = "Round 1 / 3"
	_round_label.position = Vector2(0, 75)
	_round_label.size = Vector2(1000, 40)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 22)
	_round_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_modal_panel.add_child(_round_label)

	# 自分の手
	_my_hand_label = Label.new()
	_my_hand_label.text = "?"
	_my_hand_label.position = Vector2(100, 140)
	_my_hand_label.size = Vector2(300, 200)
	_my_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_my_hand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_my_hand_label.add_theme_font_size_override("font_size", 100)
	_modal_panel.add_child(_my_hand_label)

	# VS
	_vs_label = Label.new()
	_vs_label.text = "vs"
	_vs_label.position = Vector2(400, 140)
	_vs_label.size = Vector2(200, 200)
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vs_label.add_theme_font_size_override("font_size", 40)
	_vs_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_modal_panel.add_child(_vs_label)

	# 相手の手
	_opp_hand_label = Label.new()
	_opp_hand_label.text = "?"
	_opp_hand_label.position = Vector2(600, 140)
	_opp_hand_label.size = Vector2(300, 200)
	_opp_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opp_hand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_opp_hand_label.add_theme_font_size_override("font_size", 100)
	_modal_panel.add_child(_opp_hand_label)

	# 結果ラベル
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.position = Vector2(0, 350)
	_result_label.size = Vector2(1000, 50)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 32)
	_modal_panel.add_child(_result_label)

	# G/P/C ボタン
	var btn_y: float = 440
	var btn_w: float = 200
	var btn_h: float = 80
	var gap: float = 40
	var total_w: float = btn_w * 3 + gap * 2
	var start_x: float = (1000 - total_w) / 2.0

	for hand in ["G", "P", "C"]:
		var idx: int = ["G", "P", "C"].find(hand)
		var btn := Button.new()
		btn.text = "%s %s" % [HAND_LABELS[hand], HAND_NAMES[hand]]
		btn.position = Vector2(start_x + idx * (btn_w + gap), btn_y)
		btn.size = Vector2(btn_w, btn_h)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_button_pressed.bind(hand))
		_modal_panel.add_child(btn)
		_buttons.append(btn)

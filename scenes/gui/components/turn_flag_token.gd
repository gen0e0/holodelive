class_name TurnFlagToken
extends Control

var effect_type: String = ""

var _token_body: Panel
var _effect_label: Label
var _idle_time: float = 0.0
var _base_y: float = 0.0

const TOKEN_SIZE := Vector2(80, 80)
const CORNER_RADIUS: int = 40
const LABEL_FONT_SIZE: int = 10
const FLOAT_AMPLITUDE: float = 3.0
const FLOAT_SPEED: float = 2.0

static var TYPE_CONFIG: Dictionary = {
	"skip_action": {"text": "ACTION\nSKIP", "color": Color(0.8, 0.3, 0.3)},
	"no_stage_play": {"text": "STAGE\nBAN", "color": Color(0.7, 0.4, 0.7)},
	"protection": {"text": "PROTECT", "color": Color(0.3, 0.6, 0.8)},
}


func _init() -> void:
	custom_minimum_size = TOKEN_SIZE
	size = TOKEN_SIZE
	pivot_offset = TOKEN_SIZE / 2.0


func setup(p_type: String) -> void:
	effect_type = p_type
	if is_node_ready():
		_apply_config()


func _ready() -> void:
	_build_ui()
	_apply_config()
	_base_y = position.y


func _build_ui() -> void:
	_token_body = Panel.new()
	_token_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_token_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	_token_body.add_theme_stylebox_override("panel", style)
	add_child(_token_body)

	_effect_label = Label.new()
	_effect_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_effect_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_token_body.add_child(_effect_label)


func _apply_config() -> void:
	if _token_body == null:
		return
	var config: Dictionary = TYPE_CONFIG.get(effect_type, {"text": effect_type, "color": Color(0.5, 0.5, 0.5)})
	_effect_label.text = config["text"]
	var style: StyleBoxFlat = _token_body.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = config["color"]


func _process(delta: float) -> void:
	_idle_time += delta
	position.y = _base_y + sin(_idle_time * FLOAT_SPEED) * FLOAT_AMPLITUDE


## 出現アニメーション。
func appear() -> void:
	scale = Vector2.ZERO
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


## 消滅アニメーション（シェイク → 拡大フェードアウト → queue_free）。
func consume() -> void:
	var tw: Tween = create_tween()
	# シェイク
	var orig_x: float = position.x
	tw.tween_property(self, "position:x", orig_x - 5, 0.05)
	tw.tween_property(self, "position:x", orig_x + 5, 0.05)
	tw.tween_property(self, "position:x", orig_x, 0.05)
	# 拡大 + フェードアウト
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()

class_name SDCharacter
extends Node2D

## SDキャラクター（2頭身）コンポーネント。
## Skeleton2D ベースのボーンリグで、全キャラ共通構造。
## Aseprite SpriteSheet (sd.json + sd.png) からパーツを読み込む。
##
## レイヤー命名規則:
##   - "@" を含むレイヤーのみ処理（"@" より前が識別名）
##   - グループ/レイヤーのパスでフレームキーが構成される
##   - 例: "020_name (通常@/目_開き@)" → グループ "通常", パーツ "目_開き"

# --- 日本語レイヤー名 → 内部名 マッピング ---
const LAYER_MAP: Dictionary = {
	"胴体": "body",
	"髪_背景": "hair_back",
	"顔_輪郭": "face_base",
	"髪_前景": "hair_front",
	"アクセサリ": "accessory",
}

const EXPRESSION_GROUP_MAP: Dictionary = {
	"通常": "normal",
	"ウィンク": "wink",
	"勝利": "victory",
	"負け": "lose",
}

const EXPRESSION_PART_MAP: Dictionary = {
	"目_開き": "eyes_open",
	"目_閉じ": "eyes_closed",
	"口_開き": "mouth_open",
	"口_閉じ": "mouth_closed",
	"頬": "blush",
}

# --- 設定 ---
## 手の色（肌色）
var hand_color: Color = Color(1.0, 0.87, 0.77):
	set(value):
		hand_color = value
		if _hand_l != null:
			_hand_l.get_node("Fill").color = hand_color
		if _hand_r != null:
			_hand_r.get_node("Fill").color = hand_color

## 手の半径
var hand_radius: float = 12.0

# --- ボーン位置（全キャラ共通、チューニング用） ---
var head_offset: Vector2 = Vector2.ZERO
var hand_l_offset: Vector2 = Vector2(-35, 25)
var hand_r_offset: Vector2 = Vector2(35, 25)
var hair_back_bone_offset: Vector2 = Vector2.ZERO
var hair_front_bone_offset: Vector2 = Vector2.ZERO
var accessory_bone_offset: Vector2 = Vector2.ZERO

# --- 内部ノード ---
var _body_node: Node2D
var _head_node: Node2D
var _hair_back_node: Node2D
var _hair_front_node: Node2D
var _accessory_node: Node2D
var _hand_l_node: Node2D
var _hand_r_node: Node2D

var _body_sprite: Sprite2D
var _hair_back_sprite: Sprite2D
var _face_base_sprite: Sprite2D
var _eyes_sprite: Sprite2D
var _mouth_sprite: Sprite2D
var _expression_extras: Array[Sprite2D] = []
var _hair_front_sprite: Sprite2D
var _accessory_sprite: Sprite2D
var _hand_l: Node2D
var _hand_r: Node2D

var _dir_path: String = ""
var _card_id: int = -1
var _current_expression: String = ""

# --- アニメーション ---
const BREATH_AMPLITUDE: float = 1.5
const BREATH_PERIOD: float = 2.5
const BLINK_INTERVAL_MIN: float = 6.0
const BLINK_INTERVAL_MAX: float = 12.0
const BLINK_CLOSE_DURATION: float = 0.05
const BLINK_OPEN_DURATION: float = 0.05
const BLINK_DOUBLE_GAP: float = 0.1
const TALK_OPEN_MIN: float = 0.08
const TALK_OPEN_MAX: float = 0.2
const TALK_CLOSE_MIN: float = 0.03
const TALK_CLOSE_MAX: float = 0.1

var _anim_state: String = "none"  # "none" | "idle" | "talking"
var _breathing_time: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _blink_tween: Tween = null
var _talk_timer: float = 0.0
var _mouth_is_open: bool = false
var _emote_tween: Tween = null

# スプライトシートデータ
var _spritesheet_texture: Texture2D = null
# パースされたフレーム情報: { "internal_name": Rect2, ... }
var _base_frames: Dictionary = {}
# 表情フレーム: { "expression_name": { "part_name": Rect2, ... }, ... }
var _expression_frames: Dictionary = {}


func _ready() -> void:
	set_process(false)
	_build_skeleton()


func setup(card_id: int, dir_path: String) -> void:
	_card_id = card_id
	_dir_path = dir_path
	if is_node_ready():
		_load_spritesheet()


func set_expression(expression_name: String) -> void:
	"""表情を切り替える。"""
	if _spritesheet_texture == null:
		return
	if not _expression_frames.has(expression_name):
		return
	_current_expression = expression_name
	var parts: Dictionary = _expression_frames[expression_name]

	# 目（eyes_open を優先、なければ最初の eyes_* を使用）
	if parts.has("eyes_open"):
		_set_atlas(_eyes_sprite, parts["eyes_open"])
	else:
		# eyes_* のいずれかを探す
		var found: bool = false
		for key: String in parts:
			if key.begins_with("eyes_"):
				_set_atlas(_eyes_sprite, parts[key])
				found = true
				break
		if not found:
			_eyes_sprite.visible = false

	# 口（mouth_closed を優先）
	if parts.has("mouth_closed"):
		_set_atlas(_mouth_sprite, parts["mouth_closed"])
	elif parts.has("mouth_open"):
		_set_atlas(_mouth_sprite, parts["mouth_open"])
	else:
		_mouth_sprite.visible = false

	# エクストラパーツをクリア
	for extra in _expression_extras:
		extra.queue_free()
	_expression_extras.clear()

	# eyes_*, mouth_* 以外のパーツをエクストラとして追加
	for key: String in parts:
		if key.begins_with("eyes_") or key.begins_with("mouth_"):
			continue
		var extra_sprite := Sprite2D.new()
		extra_sprite.name = "ExprExtra_" + key
		_head_node.add_child(extra_sprite)
		_head_node.move_child(extra_sprite, _mouth_sprite.get_index() + 1)
		_set_atlas(extra_sprite, parts[key])
		_expression_extras.append(extra_sprite)


func get_available_expressions() -> Array[String]:
	"""利用可能な表情名のリストを返す。"""
	var expressions: Array[String] = []
	for key: String in _expression_frames:
		expressions.append(key)
	expressions.sort()
	return expressions


func play_idle() -> void:
	"""アイドルアニメーション（呼吸+瞬き）を開始する。"""
	_start_animation("idle")


func play_talking() -> void:
	"""喋りアニメーション（呼吸+瞬き+口パク）を開始する。"""
	_start_animation("talking")


func play_emote_wave() -> void:
	"""手を振るエモーション。完了後にidleに戻る。"""
	_start_animation("idle")
	_kill_emote_tween()

	var wave_duration: float = 0.3  # 1往復の時間
	var wave_count: int = 2
	var wave_radius: float = 15.0  # 円弧の半径
	var stretch_scale: float = 1.08  # Y方向に8%引き延ばし
	var scale_pivot_y: float = 50.0  # 足先を基準にスケール
	var stretch_offset_y: float = (1.0 - stretch_scale) * scale_pivot_y  # 上に伸びるよう補正
	var total_duration: float = wave_duration * wave_count
	var ramp_up: float = 0.2
	var ramp_down: float = 0.3

	_emote_tween = create_tween()

	# 背伸び: scale.yを伸ばしつつ、足先基準になるよう位置補正
	_emote_tween.tween_property(_body_node, "scale:y", stretch_scale, ramp_up) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_emote_tween.parallel().tween_property(_body_node, "position:y", stretch_offset_y, ramp_up) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 手を振る: 円弧の1/4を往復 × wave_count
	_emote_tween.tween_method(_update_wave_hands.bind(wave_radius), 0.0, float(wave_count), total_duration)

	# 手を元の位置に戻す
	_emote_tween.tween_property(_hand_l_node, "position", hand_l_offset, ramp_down) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_emote_tween.parallel().tween_property(_hand_r_node, "position", hand_r_offset, ramp_down) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	# 背伸びから戻る
	_emote_tween.parallel().tween_property(_body_node, "scale:y", 1.0, ramp_down) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_emote_tween.parallel().tween_property(_body_node, "position:y", 0.0, ramp_down) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


func _update_wave_hands(progress: float, radius: float) -> void:
	"""手をバイバイと振る。円弧の1/4（90度分）を往復する。
	progress: 0〜wave_count。整数部=何往復目、小数部=往復内の進行。"""
	# 小数部で0→1→0の往復を作る
	var frac: float = fmod(progress, 1.0)
	var t: float = 1.0 - abs(frac * 2.0 - 1.0)  # 0→1→0 の三角波
	var tilt: float = deg_to_rad(30.0)
	var lift: float = -radius * 1.5 + 5.0

	# 左手（画面左側）: 9時方向（-PI/2）から時計回りに90度分を往復
	var l_angle: float = lerp(-PI / 2.0, -PI / 4.0, t) - tilt
	_hand_l_node.position = hand_l_offset + Vector2(
		sin(l_angle) * radius,
		lift + (-cos(l_angle) * radius)
	)
	# 右手（画面右側）: 3時方向（PI/2）から反時計回りに90度分を往復
	var r_angle: float = lerp(PI / 2.0, PI / 4.0, t) + tilt
	_hand_r_node.position = hand_r_offset + Vector2(
		sin(r_angle) * radius,
		lift + (-cos(r_angle) * radius)
	)


func _kill_emote_tween() -> void:
	if _emote_tween != null and _emote_tween.is_running():
		_emote_tween.kill()
		_emote_tween = null
		_body_node.scale = Vector2.ONE
		_body_node.position = Vector2.ZERO
		_hand_l_node.position = hand_l_offset
		_hand_r_node.position = hand_r_offset


func stop_animation() -> void:
	"""アニメーションを停止し、元の状態に戻す。"""
	_anim_state = "none"
	set_process(false)
	_breathing_time = 0.0
	_head_node.position = head_offset
	if _blink_tween != null and _blink_tween.is_running():
		_blink_tween.kill()
		_blink_tween = null
	_is_blinking = false
	_mouth_is_open = false
	_kill_emote_tween()
	_restore_eyes_open()
	_restore_mouth_closed()


func _start_animation(state: String) -> void:
	_anim_state = state
	_breathing_time = 0.0
	_schedule_next_blink()
	if state == "talking":
		_mouth_is_open = false
		_talk_timer = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _anim_state == "none":
		return

	# 呼吸: sin波で上下（idle / talking 共通）
	_breathing_time += delta
	_head_node.position.y = head_offset.y + sin(_breathing_time * TAU / BREATH_PERIOD) * BREATH_AMPLITUDE

	# 瞬き（idle / talking 共通）
	if not _is_blinking:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_do_blink()

	# 口パク（talking のみ）
	if _anim_state == "talking":
		_talk_timer -= delta
		if _talk_timer <= 0.0:
			_toggle_mouth()


func _do_blink() -> void:
	"""瞬きを実行する（1回または2回連続）。"""
	if not _has_blink_texture():
		_schedule_next_blink()
		return

	_is_blinking = true
	var blink_count: int = 1 if randf() > 0.3 else 2  # 70% で1回、30% で2回

	if _blink_tween != null and _blink_tween.is_running():
		_blink_tween.kill()
	_blink_tween = create_tween()

	for i in range(blink_count):
		if i > 0:
			_blink_tween.tween_interval(BLINK_DOUBLE_GAP)
		# 閉じる
		_blink_tween.tween_callback(_set_eyes_closed)
		_blink_tween.tween_interval(BLINK_CLOSE_DURATION)
		# 開く
		_blink_tween.tween_callback(_restore_eyes_open)
		_blink_tween.tween_interval(BLINK_OPEN_DURATION)

	_blink_tween.tween_callback(_on_blink_finished)


func _set_eyes_closed() -> void:
	"""目を閉じたテクスチャに差し替える。"""
	if _current_expression.is_empty():
		return
	var parts: Dictionary = _expression_frames.get(_current_expression, {})
	if parts.has("eyes_closed"):
		_set_atlas(_eyes_sprite, parts["eyes_closed"])


func _restore_eyes_open() -> void:
	"""目を開いたテクスチャに戻す。"""
	if _current_expression.is_empty():
		return
	var parts: Dictionary = _expression_frames.get(_current_expression, {})
	if parts.has("eyes_open"):
		_set_atlas(_eyes_sprite, parts["eyes_open"])


func _on_blink_finished() -> void:
	_is_blinking = false
	_schedule_next_blink()


func _has_blink_texture() -> bool:
	"""現在の表情に eyes_closed があるか。"""
	if _current_expression.is_empty():
		return false
	var parts: Dictionary = _expression_frames.get(_current_expression, {})
	return parts.has("eyes_closed")


func _schedule_next_blink() -> void:
	_blink_timer = randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX)


func _toggle_mouth() -> void:
	"""口の開閉を切り替える。開いている時間は長く、閉じている時間は短い。"""
	if not _has_talk_textures():
		return
	_mouth_is_open = not _mouth_is_open
	if _mouth_is_open:
		_set_mouth_open()
		_talk_timer = randf_range(TALK_OPEN_MIN, TALK_OPEN_MAX)
	else:
		_restore_mouth_closed()
		_talk_timer = randf_range(TALK_CLOSE_MIN, TALK_CLOSE_MAX)


func _set_mouth_open() -> void:
	if _current_expression.is_empty():
		return
	var parts: Dictionary = _expression_frames.get(_current_expression, {})
	if parts.has("mouth_open"):
		_set_atlas(_mouth_sprite, parts["mouth_open"])


func _restore_mouth_closed() -> void:
	if _current_expression.is_empty():
		return
	var parts: Dictionary = _expression_frames.get(_current_expression, {})
	if parts.has("mouth_closed"):
		_set_atlas(_mouth_sprite, parts["mouth_closed"])


func _has_talk_textures() -> bool:
	if _current_expression.is_empty():
		return false
	var parts: Dictionary = _expression_frames.get(_current_expression, {})
	return parts.has("mouth_open") and parts.has("mouth_closed")


# --- 内部 ---

func _build_skeleton() -> void:
	# Node2D 階層で構築（Skeleton2D/Bone2D は IK/メッシュ変形が必要になったら移行）
	# --- Body ---
	_body_node = _create_node("Body", Vector2.ZERO)
	add_child(_body_node)

	_body_sprite = Sprite2D.new()
	_body_sprite.name = "BodySprite"
	_body_node.add_child(_body_sprite)

	# --- Hands（顔より前面に描画） ---
	_hand_l_node = _create_node("HandL", hand_l_offset)
	_hand_l_node.z_index = 1
	_body_node.add_child(_hand_l_node)
	_hand_l = _create_hand_polygon()
	_hand_l.name = "HandLPoly"
	_hand_l_node.add_child(_hand_l)

	_hand_r_node = _create_node("HandR", hand_r_offset)
	_hand_r_node.z_index = 1
	_body_node.add_child(_hand_r_node)
	_hand_r = _create_hand_polygon()
	_hand_r.name = "HandRPoly"
	_hand_r_node.add_child(_hand_r)

	# --- Head ---
	_head_node = _create_node("Head", head_offset)
	_body_node.add_child(_head_node)

	# 描画順序: HairBack → FaceBase → HairFront → Eyes → Mouth → (Extras) → Accessory
	_hair_back_node = _create_node("HairBack", hair_back_bone_offset)
	_head_node.add_child(_hair_back_node)
	_hair_back_sprite = Sprite2D.new()
	_hair_back_sprite.name = "HairBackSprite"
	_hair_back_node.add_child(_hair_back_sprite)

	_face_base_sprite = Sprite2D.new()
	_face_base_sprite.name = "FaceBaseSprite"
	_head_node.add_child(_face_base_sprite)

	_hair_front_node = _create_node("HairFront", hair_front_bone_offset)
	_head_node.add_child(_hair_front_node)
	_hair_front_sprite = Sprite2D.new()
	_hair_front_sprite.name = "HairFrontSprite"
	_hair_front_node.add_child(_hair_front_sprite)

	_eyes_sprite = Sprite2D.new()
	_eyes_sprite.name = "EyesSprite"
	_head_node.add_child(_eyes_sprite)

	_mouth_sprite = Sprite2D.new()
	_mouth_sprite.name = "MouthSprite"
	_head_node.add_child(_mouth_sprite)

	_accessory_node = _create_node("Accessory", accessory_bone_offset)
	_head_node.add_child(_accessory_node)
	_accessory_sprite = Sprite2D.new()
	_accessory_sprite.name = "AccessorySprite"
	_accessory_node.add_child(_accessory_sprite)

	# テクスチャがセット済みならロード
	if not _dir_path.is_empty():
		_load_spritesheet()


func _create_node(node_name: String, pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	node.position = pos
	return node


var hand_outline_width: float = 4.0
var hand_outline_color: Color = Color.BLACK

func _create_hand_polygon() -> Node2D:
	var container := Node2D.new()
	# アウトライン（背面の大きい黒丸）
	var outline := Polygon2D.new()
	outline.name = "Outline"
	outline.polygon = _make_circle_polygon(hand_radius + hand_outline_width, 16)
	outline.color = hand_outline_color
	container.add_child(outline)
	# 手本体（前面の肌色丸）
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = _make_circle_polygon(hand_radius, 16)
	fill.color = hand_color
	container.add_child(fill)
	return container


static func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _load_spritesheet() -> void:
	var json_path: String = _dir_path + "/sd.json"
	var png_path: String = _dir_path + "/sd.png"

	if not ResourceLoader.exists(json_path) or not ResourceLoader.exists(png_path):
		push_warning("SDCharacter: sd.json or sd.png not found in %s" % _dir_path)
		return

	_spritesheet_texture = load(png_path)
	_parse_spritesheet_json(json_path)
	_apply_base_frames()

	# デフォルト表情を適用
	var expressions: Array[String] = get_available_expressions()
	if expressions.has("normal"):
		set_expression("normal")
	elif expressions.size() > 0:
		set_expression(expressions[0])


func _parse_spritesheet_json(json_path: String) -> void:
	"""sd.json をパースし、_base_frames と _expression_frames を構築する。"""
	_base_frames.clear()
	_expression_frames.clear()

	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("SDCharacter: Cannot open %s" % json_path)
		return

	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("SDCharacter: JSON parse error in %s" % json_path)
		return

	var data: Dictionary = json.data
	var frames: Dictionary = data.get("frames", {})

	for frame_key: String in frames:
		var parsed: Dictionary = _parse_frame_key(frame_key)
		if parsed.is_empty():
			continue  # @なし → 無視

		var layer_name: String = parsed["layer"]
		var group_name: String = parsed["group"]
		var frame_data: Dictionary = frames[frame_key]["frame"]
		var rect := Rect2(frame_data["x"], frame_data["y"], frame_data["w"], frame_data["h"])

		# 表情グループに属するパーツか判定
		var expr_group: String = _resolve_expression_group(group_name)
		if not expr_group.is_empty():
			var part_name: String = EXPRESSION_PART_MAP.get(layer_name, layer_name)
			if not _expression_frames.has(expr_group):
				_expression_frames[expr_group] = {}
			_expression_frames[expr_group][part_name] = rect
		else:
			# ベースパーツ
			var internal_name: String = LAYER_MAP.get(layer_name, layer_name)
			_base_frames[internal_name] = rect


func _parse_frame_key(frame_key: String) -> Dictionary:
	"""フレームキーからグループとレイヤー名を抽出する。
	例: "020_name (通常@/目_開き@)" → { "group": "通常", "layer": "目_開き" }
	例: "020_name (/胴体@)" → { "group": "", "layer": "胴体" }
	例: "020_name (/[参考]下書き)" → {} (@なし、無視)"""

	# 括弧内を抽出
	var paren_start: int = frame_key.rfind("(")
	var paren_end: int = frame_key.rfind(")")
	if paren_start < 0 or paren_end < 0:
		return {}

	var inner: String = frame_key.substr(paren_start + 1, paren_end - paren_start - 1)

	# "/" で分割
	var parts: PackedStringArray = inner.split("/")
	var group_raw: String = ""
	var layer_raw: String = ""

	if parts.size() == 2:
		group_raw = parts[0]
		layer_raw = parts[1]
	elif parts.size() == 1:
		layer_raw = parts[0]
	else:
		return {}

	# @ チェック: レイヤー名に @ がなければ無視
	if not layer_raw.contains("@"):
		return {}

	# @ より前を識別名として抽出
	var layer_name: String = layer_raw.split("@")[0].strip_edges()
	var group_name: String = group_raw.split("@")[0].strip_edges() if group_raw.contains("@") else group_raw.strip_edges()

	return { "group": group_name, "layer": layer_name }


func _resolve_expression_group(group_name: String) -> String:
	"""グループ名が表情グループかどうか判定し、内部名を返す。"""
	if group_name.is_empty():
		return ""
	return EXPRESSION_GROUP_MAP.get(group_name, "")


func _apply_base_frames() -> void:
	"""ベースパーツのスプライトにAtlasTextureを適用する。"""
	_apply_atlas(_body_sprite, "body")
	_apply_atlas(_hair_back_sprite, "hair_back")
	_apply_atlas(_face_base_sprite, "face_base")
	_apply_atlas(_hair_front_sprite, "hair_front")
	_apply_atlas(_accessory_sprite, "accessory")


func _apply_atlas(sprite: Sprite2D, part_name: String) -> void:
	"""_base_frames から AtlasTexture を生成して適用する。"""
	if _base_frames.has(part_name):
		_set_atlas(sprite, _base_frames[part_name])
	else:
		sprite.visible = false


func _set_atlas(sprite: Sprite2D, region: Rect2) -> void:
	"""スプライトシートの指定領域を AtlasTexture として設定する。"""
	var atlas := AtlasTexture.new()
	atlas.atlas = _spritesheet_texture
	atlas.region = region
	sprite.texture = atlas
	sprite.visible = true

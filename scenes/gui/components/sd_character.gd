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

# スプライトシートデータ
var _spritesheet_texture: Texture2D = null
# パースされたフレーム情報: { "internal_name": Rect2, ... }
var _base_frames: Dictionary = {}
# 表情フレーム: { "expression_name": { "part_name": Rect2, ... }, ... }
var _expression_frames: Dictionary = {}


func _ready() -> void:
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

	# 描画順序: HairBack → FaceBase → Eyes → Mouth → (Extras) → HairFront → Accessory
	_hair_back_node = _create_node("HairBack", hair_back_bone_offset)
	_head_node.add_child(_hair_back_node)
	_hair_back_sprite = Sprite2D.new()
	_hair_back_sprite.name = "HairBackSprite"
	_hair_back_node.add_child(_hair_back_sprite)

	_face_base_sprite = Sprite2D.new()
	_face_base_sprite.name = "FaceBaseSprite"
	_head_node.add_child(_face_base_sprite)

	_eyes_sprite = Sprite2D.new()
	_eyes_sprite.name = "EyesSprite"
	_head_node.add_child(_eyes_sprite)

	_mouth_sprite = Sprite2D.new()
	_mouth_sprite.name = "MouthSprite"
	_head_node.add_child(_mouth_sprite)

	_hair_front_node = _create_node("HairFront", hair_front_bone_offset)
	_head_node.add_child(_hair_front_node)
	_hair_front_sprite = Sprite2D.new()
	_hair_front_sprite.name = "HairFrontSprite"
	_hair_front_node.add_child(_hair_front_sprite)

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

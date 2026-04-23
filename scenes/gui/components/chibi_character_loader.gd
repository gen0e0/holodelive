class_name ChibiCharacterLoader extends RefCounted

## Aseprite の書き出し JSON + PNG を読んで ChibiCharacterData を生成する。
##
## 命名規約:
##   パーツ:   "name@コメント"            例: "upper_arm_r@右上腕"
##   ピボット: "#x,y@コメント"            例: "#112,128@右肩"（親グループが "#pivot@..."）
##   表情:    "expressions@..." 配下の "group@..." 配下に部位
##
## `@` 以降はデザイナー自由コメント（パース時に破棄）。

const PIVOT_GROUP_ID: String = "#pivot"
const EXPRESSIONS_GROUP_ID: String = "expressions"


## JSON ファイルのパスからロードする。失敗時は null を返す。
static func load_from_json(json_path: String) -> ChibiCharacterData:
	if not FileAccess.file_exists(json_path):
		push_error("ChibiCharacterLoader: JSON not found: %s" % json_path)
		return null
	var text: String = FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ChibiCharacterLoader: invalid JSON: %s" % json_path)
		return null
	var base_dir: String = json_path.get_base_dir()
	return _build(parsed, base_dir)


static func _build(json: Dictionary, base_dir: String) -> ChibiCharacterData:
	var data := ChibiCharacterData.new()

	var meta: Dictionary = json.get("meta", {})
	var image_name: String = meta.get("image", "")
	if image_name == "":
		push_error("ChibiCharacterLoader: meta.image is empty")
		return null
	var image_path: String = base_dir.path_join(image_name)
	data.texture = _load_texture(image_path)
	if data.texture == null:
		return null

	var layers: Array = meta.get("layers", [])
	var layer_info: Dictionary = _build_layer_info(layers)

	var frames: Dictionary = json.get("frames", {})
	for frame_key: String in frames.keys():
		var frame_data: Dictionary = frames[frame_key]
		var rect: Rect2i = _rect_from_frame(frame_data)
		if data.frame_size == Vector2i.ZERO:
			data.frame_size = rect.size

		var layer_full: String = _extract_layer_name(frame_key)
		if not layer_info.has(layer_full):
			push_warning("ChibiCharacterLoader: layer not found for frame: %s" % frame_key)
			continue
		var info: Dictionary = layer_info[layer_full]
		_categorize(data, layer_info, info, rect)

	return data


## PNG を Image.load 経由で読み込む（.import がなくても動くようにするため）。
static func _load_texture(image_path: String) -> Texture2D:
	var abs_path: String = ProjectSettings.globalize_path(image_path) if image_path.begins_with("res://") else image_path
	if not FileAccess.file_exists(image_path) and not FileAccess.file_exists(abs_path):
		push_error("ChibiCharacterLoader: texture not found: %s" % image_path)
		return null
	var img := Image.new()
	var err: int = img.load(abs_path)
	if err != OK:
		push_error("ChibiCharacterLoader: Image.load failed (%d): %s" % [err, abs_path])
		return null
	return ImageTexture.create_from_image(img)


## meta.layers を解析して full_name -> {id, full, group_full, is_group} の辞書にする。
## グループノード（blendMode を持たない）も辞書に含めて親チェーン解決に使う。
static func _build_layer_info(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer: Dictionary in layers:
		var full: String = layer.get("name", "")
		if full == "":
			continue
		var group_full: String = layer.get("group", "")
		var has_blend: bool = layer.has("blendMode")
		result[full] = {
			"full": full,
			"id": _split_identifier(full),
			"group_full": group_full,
			"is_group": not has_blend,
		}
	return result


## "name@コメント" → "name"
static func _split_identifier(full: String) -> String:
	var at: int = full.find("@")
	if at < 0:
		return full
	return full.substr(0, at)


## "000_sample (upper_arm_r@右上腕).aseprite" → "upper_arm_r@右上腕"
static func _extract_layer_name(frame_key: String) -> String:
	var open: int = frame_key.rfind(" (")
	var close: int = frame_key.rfind(")")
	if open < 0 or close < 0 or close <= open:
		return frame_key
	return frame_key.substr(open + 2, close - open - 2)


static func _rect_from_frame(frame_data: Dictionary) -> Rect2i:
	var f: Dictionary = frame_data.get("frame", {})
	return Rect2i(int(f.get("x", 0)), int(f.get("y", 0)), int(f.get("w", 0)), int(f.get("h", 0)))


## 親グループを子→先祖方向に遡り、各グループの full_name を順に返す。
static func _ancestor_chain(layer_info: Dictionary, info: Dictionary) -> Array:
	var result: Array = []
	var current_group: String = info.group_full
	while current_group != "":
		result.append(current_group)
		if not layer_info.has(current_group):
			break
		current_group = layer_info[current_group].group_full
	return result


## 1レイヤーを parts / pivots / expressions のどれかに分類して data に書き込む。
static func _categorize(data: ChibiCharacterData, layer_info: Dictionary, info: Dictionary, rect: Rect2i) -> void:
	if info.is_group:
		return

	var ancestors: Array = _ancestor_chain(layer_info, info)

	if _contains_group_id(ancestors, PIVOT_GROUP_ID):
		_add_pivot(data, info)
		return

	var expr_group: String = _find_expression_group(ancestors)
	if expr_group != "":
		var map: Dictionary = data.expressions.get(expr_group, {})
		map[info.id] = rect
		data.expressions[expr_group] = map
		return

	# 通常パーツ
	data.parts[info.id] = rect
	var parent_id: String = ""
	if info.group_full != "":
		parent_id = _split_identifier(info.group_full)
	data.part_groups[info.id] = parent_id


static func _contains_group_id(ancestors: Array, group_id: String) -> bool:
	for a: String in ancestors:
		if _split_identifier(a) == group_id:
			return true
	return false


## expressions@... の**直下**のグループ識別子を返す。見つからなければ空文字。
## ancestors は [直接親, 祖父母, ...] の順で格納されている想定。
static func _find_expression_group(ancestors: Array) -> String:
	var last_before: String = ""
	for a: String in ancestors:
		if _split_identifier(a) == EXPRESSIONS_GROUP_ID:
			return last_before
		last_before = _split_identifier(a)
	return ""


## ピボット行を data に追加する。id が "#x,y" の形式。
static func _add_pivot(data: ChibiCharacterData, info: Dictionary) -> void:
	var coord: String = info.id.substr(1)  # 先頭の # を除く
	var parts_str: PackedStringArray = coord.split(",")
	if parts_str.size() != 2:
		push_warning("ChibiCharacterLoader: invalid pivot id: %s" % info.id)
		return
	var x: int = int(parts_str[0])
	var y: int = int(parts_str[1])
	var joint_name: String = ""
	var at: int = info.full.find("@")
	if at >= 0:
		joint_name = info.full.substr(at + 1)
	else:
		joint_name = info.id
	data.pivots[joint_name] = Vector2i(x, y)

class_name ChibiCharacter extends Node2D

## Skeleton2D 風の骨格を持つ Chibi キャラクター。
## ChibiCharacterLoader でパースした ChibiCharacterData からボーン階層と
## Sprite2D を自動構築する。ボーンは Node2D で実装し、各ボーンを回転させれば
## 配下のパーツも連動して動く。
##
## 原点（ChibiCharacter.position）はキャラの「丹田」位置に合わせる。

## 骨格階層: 子 → 親（根は "" を親とする）
const BONE_HIERARCHY: Dictionary = {
	"丹田": "",
	"首の付け根": "丹田",
	"右肩": "丹田",
	"左肩": "丹田",
	"右肘": "右肩",
	"左肘": "左肩",
	"右手首": "右肘",
	"左手首": "左肘",
	"右股関節": "丹田",
	"左股関節": "丹田",
	"右膝": "右股関節",
	"左膝": "左股関節",
	"右足首": "右膝",
	"左足首": "左膝",
}

## 骨格構築順（親が先）
const BONE_ORDER: Array = [
	"丹田", "首の付け根",
	"右肩", "右肘", "右手首",
	"左肩", "左肘", "左手首",
	"右股関節", "右膝", "右足首",
	"左股関節", "左膝", "左足首",
]

## パーツ識別子 → 所属ボーン名
const PART_TO_BONE: Dictionary = {
	"torso": "丹田",
	"hair_back": "首の付け根",
	"face_base": "首の付け根",
	"hair_front": "首の付け根",
	"upper_arm_r": "右肩",
	"lower_arm_r": "右肘",
	"hand_r": "右手首",
	"upper_arm_l": "左肩",
	"lower_arm_l": "左肘",
	"hand_l": "左手首",
	"upper_leg_r": "右股関節",
	"lower_leg_r": "右膝",
	"foot_r": "右足首",
	"upper_leg_l": "左股関節",
	"lower_leg_l": "左膝",
	"foot_l": "左足首",
}

## レンダリング順（z_index）
const Z_INDEX: Dictionary = {
	"hair_back": 0,
	"upper_leg_r": 5, "lower_leg_r": 5, "foot_r": 5,
	"upper_leg_l": 5, "lower_leg_l": 5, "foot_l": 5,
	"torso": 10,
	"upper_arm_r": 15, "lower_arm_r": 15, "hand_r": 15,
	"upper_arm_l": 15, "lower_arm_l": 15, "hand_l": 15,
	"face_base": 20,
	"hair_front": 30,
}
const Z_INDEX_EXPRESSION: int = 25

var _data: ChibiCharacterData
var _bones: Dictionary = {}                # joint_name(String) -> Node2D
var _part_sprites: Dictionary = {}         # part_id(String) -> Sprite2D
var _expression_sprites: Dictionary = {}   # group -> {part_id -> Sprite2D}
var _current_expression: String = "normal"
var _eye_state: String = "opened"          # "opened" | "closed"
var _mouth_state: String = "closed"        # "closed" | "opened"


## JSON パスからロードしてキャラを組み立てる。
func load_from_json(json_path: String) -> bool:
	var data: ChibiCharacterData = ChibiCharacterLoader.load_from_json(json_path)
	if data == null:
		return false
	_data = data
	_build()
	return true


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_bones.clear()
	_part_sprites.clear()
	_expression_sprites.clear()

	_build_bones()
	_build_parts()
	_build_expressions()
	set_expression(_current_expression)


func _build_bones() -> void:
	for joint: String in BONE_ORDER:
		if not _data.pivots.has(joint):
			push_warning("ChibiCharacter: missing pivot: %s" % joint)
			continue
		var bone := Node2D.new()
		bone.name = joint
		bone.set_meta("canvas_pivot", Vector2(_data.pivots[joint]))
		_bones[joint] = bone

		var parent_joint: String = BONE_HIERARCHY[joint]
		if parent_joint == "":
			add_child(bone)
			bone.position = Vector2.ZERO
		else:
			var parent_bone: Node2D = _bones[parent_joint]
			parent_bone.add_child(bone)
			var pivot: Vector2 = Vector2(_data.pivots[joint])
			var parent_pivot: Vector2 = Vector2(_data.pivots[parent_joint])
			bone.position = pivot - parent_pivot


func _build_parts() -> void:
	for part_id: String in _data.parts.keys():
		var bone_name: String = PART_TO_BONE.get(part_id, "丹田")
		if not _bones.has(bone_name):
			push_warning("ChibiCharacter: bone not found for part: %s -> %s" % [part_id, bone_name])
			continue
		var bone: Node2D = _bones[bone_name]
		var pivot: Vector2 = bone.get_meta("canvas_pivot")
		var sprite := _make_sprite(_data.parts[part_id], pivot)
		sprite.name = part_id
		sprite.z_index = Z_INDEX.get(part_id, 0)
		bone.add_child(sprite)
		_part_sprites[part_id] = sprite


func _build_expressions() -> void:
	if not _bones.has("首の付け根"):
		return
	var neck: Node2D = _bones["首の付け根"]
	var pivot: Vector2 = neck.get_meta("canvas_pivot")
	for group_name: String in _data.expressions.keys():
		var expr_map: Dictionary = _data.expressions[group_name]
		var sprites: Dictionary = {}
		for part_id: String in expr_map.keys():
			var sprite := _make_sprite(expr_map[part_id], pivot)
			sprite.name = "%s_%s" % [group_name, part_id]
			sprite.visible = false
			sprite.z_index = Z_INDEX_EXPRESSION
			neck.add_child(sprite)
			sprites[part_id] = sprite
		_expression_sprites[group_name] = sprites


## 指定した矩形を Sprite2D として生成。ボーンのピボット座標に原点を合わせる。
func _make_sprite(rect: Rect2i, pivot: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _data.texture
	s.region_enabled = true
	s.region_rect = Rect2(rect)
	s.centered = false
	s.offset = -pivot
	return s


## 表情グループを切り替える（例: "normal"）。
func set_expression(group: String) -> void:
	if not _expression_sprites.has(group):
		return
	_current_expression = group
	for g: String in _expression_sprites.keys():
		for p: String in _expression_sprites[g].keys():
			_expression_sprites[g][p].visible = false
	_apply_face_state()


## 目の状態を切り替える（"opened" | "closed"）。
func set_eye_state(state: String) -> void:
	_eye_state = state
	_apply_face_state()


## 口の状態を切り替える（"opened" | "closed"）。
func set_mouth_state(state: String) -> void:
	_mouth_state = state
	_apply_face_state()


func _apply_face_state() -> void:
	if not _expression_sprites.has(_current_expression):
		return
	var map: Dictionary = _expression_sprites[_current_expression]
	_set_visible(map, "eyes_opened", _eye_state == "opened")
	_set_visible(map, "eyes_closed", _eye_state == "closed")
	_set_visible(map, "mouth_opened", _mouth_state == "opened")
	_set_visible(map, "mouth_closed", _mouth_state == "closed")


func _set_visible(map: Dictionary, key: String, visible_: bool) -> void:
	if map.has(key):
		map[key].visible = visible_


## ボーン Node2D を取得（外部からアニメーションするため）。
func get_bone(joint_name: String) -> Node2D:
	return _bones.get(joint_name)


## 利用可能な表情名を返す。
func get_available_expressions() -> Array[String]:
	var arr: Array[String] = []
	for k: String in _expression_sprites.keys():
		arr.append(k)
	return arr

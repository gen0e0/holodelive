class_name ChibiCharacterLoaderTest
extends GdUnitTestSuite

## artwork/chibi/000_sample.json を実データとして使って全体パースを検証する。

const SAMPLE_JSON: String = "res://artwork/chibi/000_sample.json"

var _data: ChibiCharacterData


func before() -> void:
	_data = ChibiCharacterLoader.load_from_json(SAMPLE_JSON)


func test_data_not_null() -> void:
	assert_object(_data).is_not_null()


func test_texture_loaded() -> void:
	assert_object(_data.texture).is_not_null()


func test_frame_size() -> void:
	assert_int(_data.frame_size.x).is_equal(240)
	assert_int(_data.frame_size.y).is_equal(240)


func test_parts_include_both_sides() -> void:
	# 左右独立命名なので両方あるべき
	assert_bool(_data.parts.has("upper_arm_r")).is_true()
	assert_bool(_data.parts.has("upper_arm_l")).is_true()
	assert_bool(_data.parts.has("upper_leg_r")).is_true()
	assert_bool(_data.parts.has("upper_leg_l")).is_true()


func test_top_level_parts() -> void:
	assert_bool(_data.parts.has("hair_back")).is_true()
	assert_bool(_data.parts.has("torso")).is_true()
	assert_bool(_data.parts.has("face_base")).is_true()
	assert_bool(_data.parts.has("hair_front")).is_true()


func test_part_rect_matches_json() -> void:
	# hair_back は先頭 y=0 の 240x240
	var rect: Rect2i = _data.parts["hair_back"]
	assert_int(rect.position.x).is_equal(0)
	assert_int(rect.position.y).is_equal(0)
	assert_int(rect.size.x).is_equal(240)
	assert_int(rect.size.y).is_equal(240)


func test_part_groups() -> void:
	# arm_r@右腕 配下のパーツ
	assert_str(_data.part_groups["upper_arm_r"]).is_equal("arm_r")
	assert_str(_data.part_groups["lower_arm_r"]).is_equal("arm_r")
	assert_str(_data.part_groups["hand_r"]).is_equal("arm_r")
	# トップレベルパーツはグループ無し
	assert_str(_data.part_groups["hair_back"]).is_equal("")
	assert_str(_data.part_groups["torso"]).is_equal("")


func test_expression_normal_has_four_parts() -> void:
	assert_bool(_data.expressions.has("normal")).is_true()
	var normal_map: Dictionary = _data.expressions["normal"]
	assert_bool(normal_map.has("eyes_opened")).is_true()
	assert_bool(normal_map.has("eyes_closed")).is_true()
	assert_bool(normal_map.has("mouth_opened")).is_true()
	assert_bool(normal_map.has("mouth_closed")).is_true()


func test_expression_parts_not_in_parts_dict() -> void:
	# 表情部位は parts ではなく expressions に入るべき
	assert_bool(_data.parts.has("eyes_opened")).is_false()
	assert_bool(_data.parts.has("mouth_closed")).is_false()


func test_pivots_all_14() -> void:
	var expected: Array[String] = [
		"右足首", "左足首", "右膝", "左膝",
		"右股関節", "左股関節", "丹田",
		"右手首", "左手首", "右肘", "左肘",
		"右肩", "左肩", "首の付け根",
	]
	for name: String in expected:
		assert_bool(_data.pivots.has(name)).override_failure_message("pivot missing: %s" % name).is_true()
	assert_int(_data.pivots.size()).is_equal(14)


func test_pivot_coordinates() -> void:
	assert_vector(_data.pivots["右肩"]).is_equal(Vector2i(112, 128))
	assert_vector(_data.pivots["左肩"]).is_equal(Vector2i(128, 128))
	assert_vector(_data.pivots["丹田"]).is_equal(Vector2i(120, 148))
	assert_vector(_data.pivots["首の付け根"]).is_equal(Vector2i(120, 120))


func test_pivots_not_in_parts() -> void:
	# ピボットは parts に混入してはいけない
	for id: String in _data.parts.keys():
		assert_bool(id.begins_with("#")).override_failure_message("pivot leaked into parts: %s" % id).is_false()

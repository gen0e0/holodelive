class_name DebugSceneTest
extends GdUnitTestSuite

# debug_scene.gd の static メソッドをテスト

var _scene_script: GDScript


func before() -> void:
	_scene_script = load("res://scenes/debug/debug_scene.gd")


# =============================================================================
# _parse_zone_args
# =============================================================================

func test_parse_empty_args() -> void:
	var result: Dictionary = _scene_script._parse_zone_args([])
	assert_dict(result).is_empty()


func test_parse_single_hand() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["p0=6,3"])
	assert_dict(result).has_size(1)
	assert_array(result["p0"]).contains_exactly([6, 3])


func test_parse_multiple_zones() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["p0=6,3", "s1=40"])
	assert_dict(result).has_size(2)
	assert_array(result["p0"]).contains_exactly([6, 3])
	assert_array(result["s1"]).contains_exactly([40])


func test_parse_backstage() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["b0=10"])
	assert_dict(result).has_size(1)
	assert_array(result["b0"]).contains_exactly([10])


func test_parse_home() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["h=1,2,3"])
	assert_dict(result).has_size(1)
	assert_array(result["h"]).contains_exactly([1, 2, 3])


func test_parse_random_card() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["s0=r,r,r"])
	assert_dict(result).has_size(1)
	assert_array(result["s0"]).contains_exactly([-1, -1, -1])


func test_parse_random_mixed_with_ids() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["p0=r,6"])
	assert_dict(result).has_size(1)
	assert_array(result["p0"]).contains_exactly([-1, 6])


func test_parse_random_uppercase() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["s1=R,10,R"])
	assert_dict(result).has_size(1)
	assert_array(result["s1"]).contains_exactly([-1, 10, -1])


func test_parse_all_zones() -> void:
	var result: Dictionary = _scene_script._parse_zone_args([
		"p0=1,2", "p1=3", "s0=10,20,30", "s1=40", "b0=50", "b1=60", "h=7"
	])
	assert_dict(result).has_size(7)


func test_parse_ignores_invalid_key() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["x0=1", "d0=2", "h2=3"])
	assert_dict(result).is_empty()


func test_parse_ignores_bad_format() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["p0", "=5", ""])
	assert_dict(result).is_empty()


func test_parse_case_insensitive() -> void:
	var result: Dictionary = _scene_script._parse_zone_args(["P0=6,3", "S1=40"])
	assert_dict(result).has_size(2)
	assert_array(result["p0"]).contains_exactly([6, 3])


func test_parse_with_spaces() -> void:
	var result: Dictionary = _scene_script._parse_zone_args([" p0 = 6 , 3 "])
	assert_dict(result).has_size(1)
	assert_array(result["p0"]).contains_exactly([6, 3])


# =============================================================================
# _find_and_remove_from_current_zone
# =============================================================================

func test_find_and_remove_from_deck() -> void:
	var state := GameState.new()
	var iid: int = state.create_instance(6)
	state.deck.append(iid)

	var found: int = _scene_script._find_and_remove_from_current_zone(state, 6)
	assert_int(found).is_equal(iid)
	assert_array(state.deck).is_empty()


func test_find_and_remove_from_hand() -> void:
	var state := GameState.new()
	var iid: int = state.create_instance(10)
	state.hands[0].append(iid)

	var found: int = _scene_script._find_and_remove_from_current_zone(state, 10)
	assert_int(found).is_equal(iid)
	assert_array(state.hands[0]).is_empty()


func test_find_and_remove_from_stage() -> void:
	var state := GameState.new()
	var iid: int = state.create_instance(20)
	state.stages[1].append(iid)

	var found: int = _scene_script._find_and_remove_from_current_zone(state, 20)
	assert_int(found).is_equal(iid)
	assert_array(state.stages[1]).is_empty()


func test_find_and_remove_from_backstage() -> void:
	var state := GameState.new()
	var iid: int = state.create_instance(30)
	state.backstages[0] = iid

	var found: int = _scene_script._find_and_remove_from_current_zone(state, 30)
	assert_int(found).is_equal(iid)
	assert_int(state.backstages[0]).is_equal(-1)


func test_find_and_remove_from_home() -> void:
	var state := GameState.new()
	var iid: int = state.create_instance(50)
	state.home.append(iid)

	var found: int = _scene_script._find_and_remove_from_current_zone(state, 50)
	assert_int(found).is_equal(iid)
	assert_array(state.home).is_empty()


func test_find_and_remove_not_found() -> void:
	var state := GameState.new()
	var found: int = _scene_script._find_and_remove_from_current_zone(state, 99)
	assert_int(found).is_equal(-1)

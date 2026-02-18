class_name ZoneOpsTest
extends GdUnitTestSuite

func _create_state_with_hand(player: int, count: int) -> GameState:
	var state := GameState.new()
	for i in range(count):
		var id := state.create_instance(i)
		state.hands[player].append(id)
	return state

func _create_state_with_deck(count: int) -> GameState:
	var state := GameState.new()
	for i in range(count):
		var id := state.create_instance(i)
		state.deck.append(id)
	return state

# --- draw_card ---

func test_draw_card() -> void:
	var state := _create_state_with_deck(5)
	var rec := DiffRecorder.new()
	var drawn := ZoneOps.draw_card(state, 0, rec)
	assert_int(drawn).is_equal(0)
	assert_int(state.deck.size()).is_equal(4)
	assert_int(state.hands[0].size()).is_equal(1)
	assert_array(rec.diffs).has_size(1)

func test_draw_card_empty_deck() -> void:
	var state := GameState.new()
	var rec := DiffRecorder.new()
	var drawn := ZoneOps.draw_card(state, 0, rec)
	assert_int(drawn).is_equal(-1)
	assert_array(rec.diffs).is_empty()

# --- play_to_stage ---

func test_play_to_stage() -> void:
	var state := _create_state_with_hand(0, 3)
	var rec := DiffRecorder.new()
	var ok := ZoneOps.play_to_stage(state, 0, 0, rec)
	assert_bool(ok).is_true()
	assert_bool(state.stages[0].has(0)).is_true()
	assert_int(state.hands[0].size()).is_equal(2)
	assert_bool(state.instances[0].face_down).is_false()

func test_play_to_stage_appends() -> void:
	var state := _create_state_with_hand(0, 2)
	var rec := DiffRecorder.new()
	state.stages[0].append(100)  # 1枚配置済み
	var ok := ZoneOps.play_to_stage(state, 0, 0, rec)
	assert_bool(ok).is_true()
	assert_int(state.stages[0].size()).is_equal(2)
	assert_int(state.stages[0][1]).is_equal(0)

func test_play_to_stage_full() -> void:
	var state := _create_state_with_hand(0, 1)
	var rec := DiffRecorder.new()
	state.stages[0].append(100)
	state.stages[0].append(101)
	state.stages[0].append(102)
	var ok := ZoneOps.play_to_stage(state, 0, 0, rec)
	assert_bool(ok).is_false()

func test_play_to_stage_not_in_hand() -> void:
	var state := _create_state_with_hand(0, 1)
	var rec := DiffRecorder.new()
	var ok := ZoneOps.play_to_stage(state, 0, 999, rec)
	assert_bool(ok).is_false()

# --- play_to_backstage ---

func test_play_to_backstage() -> void:
	var state := _create_state_with_hand(1, 2)
	var rec := DiffRecorder.new()
	var ok := ZoneOps.play_to_backstage(state, 1, 0, rec)
	assert_bool(ok).is_true()
	assert_int(state.backstages[1]).is_equal(0)
	assert_bool(state.instances[0].face_down).is_true()
	assert_int(state.hands[1].size()).is_equal(1)

func test_play_to_backstage_occupied() -> void:
	var state := _create_state_with_hand(0, 1)
	state.backstages[0] = 100
	var rec := DiffRecorder.new()
	var ok := ZoneOps.play_to_backstage(state, 0, 0, rec)
	assert_bool(ok).is_false()

# --- open_backstage ---

func test_open_backstage() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.backstages[0] = id
	state.instances[id].face_down = true
	var rec := DiffRecorder.new()
	var ok := ZoneOps.open_backstage(state, 0, rec)
	assert_bool(ok).is_true()
	assert_bool(state.instances[id].face_down).is_false()
	assert_array(rec.diffs).has_size(1)

func test_open_backstage_empty() -> void:
	var state := GameState.new()
	var rec := DiffRecorder.new()
	var ok := ZoneOps.open_backstage(state, 0, rec)
	assert_bool(ok).is_false()

func test_open_backstage_already_open() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.backstages[0] = id
	state.instances[id].face_down = false
	var rec := DiffRecorder.new()
	var ok := ZoneOps.open_backstage(state, 0, rec)
	assert_bool(ok).is_false()

# --- move_to_home ---

func test_move_to_home_from_stage() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.stages[0].append(id)
	var rec := DiffRecorder.new()
	ZoneOps.move_to_home(state, id, rec)
	assert_bool(state.stages[0].has(id)).is_false()
	assert_bool(state.home.has(id)).is_true()
	assert_array(rec.diffs).has_size(1)

# --- remove_card ---

func test_remove_card_from_home() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.home.append(id)
	var rec := DiffRecorder.new()
	ZoneOps.remove_card(state, id, rec)
	assert_bool(state.home.has(id)).is_false()
	assert_bool(state.removed.has(id)).is_true()

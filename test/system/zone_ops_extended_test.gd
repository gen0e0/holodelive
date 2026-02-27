extends GdUnitTestSuite

# --- move_to_hand ---

func test_move_to_hand_from_stage() -> void:
	var state := GameState.new()
	var id: int = state.create_instance(1)
	state.stages[0].append(id)
	var rec := DiffRecorder.new()
	ZoneOps.move_to_hand(state, id, 0, rec)
	assert_bool(state.stages[0].has(id)).is_false()
	assert_bool(state.hands[0].has(id)).is_true()
	assert_array(rec.diffs).has_size(1)

func test_move_to_hand_from_home() -> void:
	var state := GameState.new()
	var id: int = state.create_instance(1)
	state.home.append(id)
	var rec := DiffRecorder.new()
	ZoneOps.move_to_hand(state, id, 1, rec)
	assert_bool(state.home.has(id)).is_false()
	assert_bool(state.hands[1].has(id)).is_true()

func test_move_to_hand_from_deck() -> void:
	var state := GameState.new()
	var id: int = state.create_instance(1)
	state.deck.append(id)
	var rec := DiffRecorder.new()
	ZoneOps.move_to_hand(state, id, 0, rec)
	assert_bool(state.deck.has(id)).is_false()
	assert_bool(state.hands[0].has(id)).is_true()

# --- move_to_deck_top ---

func test_move_to_deck_top_from_hand() -> void:
	var state := GameState.new()
	var id: int = state.create_instance(1)
	state.hands[0].append(id)
	var existing: int = state.create_instance(2)
	state.deck.append(existing)
	var rec := DiffRecorder.new()
	ZoneOps.move_to_deck_top(state, id, rec)
	assert_bool(state.hands[0].has(id)).is_false()
	assert_int(state.deck[0]).is_equal(id)
	assert_int(state.deck.size()).is_equal(2)

func test_move_to_deck_top_from_stage() -> void:
	var state := GameState.new()
	var id: int = state.create_instance(1)
	state.stages[1].append(id)
	var rec := DiffRecorder.new()
	ZoneOps.move_to_deck_top(state, id, rec)
	assert_bool(state.stages[1].has(id)).is_false()
	assert_int(state.deck[0]).is_equal(id)

# --- move_to_deck_bottom ---

func test_move_to_deck_bottom_from_hand() -> void:
	var state := GameState.new()
	var existing: int = state.create_instance(2)
	state.deck.append(existing)
	var id: int = state.create_instance(1)
	state.hands[0].append(id)
	var rec := DiffRecorder.new()
	ZoneOps.move_to_deck_bottom(state, id, rec)
	assert_bool(state.hands[0].has(id)).is_false()
	assert_int(state.deck.back()).is_equal(id)
	assert_int(state.deck.size()).is_equal(2)

# --- play_to_stage_from_zone ---

func test_play_to_stage_from_zone_home() -> void:
	var state := GameState.new()
	var id: int = state.create_instance(1)
	state.home.append(id)
	state.instances[id].face_down = true
	var rec := DiffRecorder.new()
	var ok: bool = ZoneOps.play_to_stage_from_zone(state, 0, id, rec)
	assert_bool(ok).is_true()
	assert_bool(state.home.has(id)).is_false()
	assert_bool(state.stages[0].has(id)).is_true()
	assert_bool(state.instances[id].face_down).is_false()

func test_play_to_stage_from_zone_full() -> void:
	var state := GameState.new()
	for i in range(3):
		var sid: int = state.create_instance(i)
		state.stages[0].append(sid)
	var id: int = state.create_instance(99)
	state.home.append(id)
	var rec := DiffRecorder.new()
	var ok: bool = ZoneOps.play_to_stage_from_zone(state, 0, id, rec)
	assert_bool(ok).is_false()

# --- play_to_backstage_from_zone ---

func test_play_to_backstage_from_zone_deck() -> void:
	var state := GameState.new()
	var id: int = state.create_instance(1)
	state.deck.append(id)
	var rec := DiffRecorder.new()
	var ok: bool = ZoneOps.play_to_backstage_from_zone(state, 1, id, rec)
	assert_bool(ok).is_true()
	assert_bool(state.deck.has(id)).is_false()
	assert_int(state.backstages[1]).is_equal(id)
	assert_bool(state.instances[id].face_down).is_true()

func test_play_to_backstage_from_zone_occupied() -> void:
	var state := GameState.new()
	var existing: int = state.create_instance(1)
	state.backstages[0] = existing
	var id: int = state.create_instance(2)
	state.home.append(id)
	var rec := DiffRecorder.new()
	var ok: bool = ZoneOps.play_to_backstage_from_zone(state, 0, id, rec)
	assert_bool(ok).is_false()

# --- field_effects ---

func test_field_effects_tick_on_start_turn() -> void:
	var registry := CardRegistry.new()
	var state := GameState.new()
	state.field_effects.append(FieldEffect.new("skip_action", 0, -1, 1))
	state.field_effects.append(FieldEffect.new("protection", 0, -1, 0))
	# デッキに1枚入れてドローできるようにする
	var id: int = state.create_instance(1)
	state.deck.append(id)
	var controller := GameController.new(state, registry)
	controller.start_turn()
	# lifetime=0 は除去、lifetime=1 はデクリメントされて 0 に
	assert_int(state.field_effects.size()).is_equal(1)
	var fe: FieldEffect = state.field_effects[0]
	assert_str(fe.type).is_equal("skip_action")
	assert_int(fe.lifetime).is_equal(0)

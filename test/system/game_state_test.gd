class_name GameStateTest
extends GdUnitTestSuite

# --- 初期値テスト ---

func test_initial_values() -> void:
	var state := GameState.new()
	assert_int(state.next_instance_id).is_equal(0)
	assert_dict(state.instances).is_empty()
	assert_array(state.deck).is_empty()
	assert_int(state.current_player).is_equal(0)
	assert_int(state.phase).is_equal(Enums.Phase.ACTION)
	assert_int(state.round_number).is_equal(1)
	assert_int(state.turn_number).is_equal(1)

func test_initial_zones() -> void:
	var state := GameState.new()
	# hands: 2 empty arrays
	assert_int(state.hands.size()).is_equal(2)
	assert_array(state.hands[0]).is_empty()
	assert_array(state.hands[1]).is_empty()
	# stages: 2 players x 3 slots, all -1
	assert_int(state.stages[0][0]).is_equal(-1)
	assert_int(state.stages[1][2]).is_equal(-1)
	# backstages: 2 slots, both -1
	assert_int(state.backstages[0]).is_equal(-1)
	assert_int(state.backstages[1]).is_equal(-1)
	# shared zones
	assert_array(state.home).is_empty()
	assert_array(state.removed).is_empty()

func test_initial_round_wins() -> void:
	var state := GameState.new()
	assert_int(state.round_wins[0]).is_equal(0)
	assert_int(state.round_wins[1]).is_equal(0)

func test_initial_live_ready() -> void:
	var state := GameState.new()
	assert_bool(state.live_ready[0]).is_false()
	assert_bool(state.live_ready[1]).is_false()
	assert_int(state.live_ready_turn[0]).is_equal(-1)
	assert_int(state.live_ready_turn[1]).is_equal(-1)

# --- create_instance ---

func test_create_instance() -> void:
	var state := GameState.new()
	var id0 := state.create_instance(100)
	assert_int(id0).is_equal(0)
	assert_int(state.next_instance_id).is_equal(1)
	assert_bool(state.instances.has(0)).is_true()
	var inst: CardInstance = state.instances[0]
	assert_int(inst.instance_id).is_equal(0)
	assert_int(inst.card_id).is_equal(100)

func test_create_instance_increments_id() -> void:
	var state := GameState.new()
	var id0 := state.create_instance(1)
	var id1 := state.create_instance(2)
	var id2 := state.create_instance(3)
	assert_int(id0).is_equal(0)
	assert_int(id1).is_equal(1)
	assert_int(id2).is_equal(2)
	assert_int(state.instances.size()).is_equal(3)

# --- find_zone ---

func test_find_zone_deck() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.deck.append(id)
	var zone := state.find_zone(id)
	assert_str(zone["zone"]).is_equal("deck")
	assert_int(zone["player"]).is_equal(-1)

func test_find_zone_hand() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.hands[1].append(id)
	var zone := state.find_zone(id)
	assert_str(zone["zone"]).is_equal("hand")
	assert_int(zone["player"]).is_equal(1)

func test_find_zone_stage() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.stages[0][2] = id
	var zone := state.find_zone(id)
	assert_str(zone["zone"]).is_equal("stage")
	assert_int(zone["player"]).is_equal(0)
	assert_int(zone["index"]).is_equal(2)

func test_find_zone_backstage() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.backstages[0] = id
	var zone := state.find_zone(id)
	assert_str(zone["zone"]).is_equal("backstage")
	assert_int(zone["player"]).is_equal(0)

func test_find_zone_home() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.home.append(id)
	var zone := state.find_zone(id)
	assert_str(zone["zone"]).is_equal("home")

func test_find_zone_removed() -> void:
	var state := GameState.new()
	var id := state.create_instance(1)
	state.removed.append(id)
	var zone := state.find_zone(id)
	assert_str(zone["zone"]).is_equal("removed")

func test_find_zone_not_found() -> void:
	var state := GameState.new()
	var zone := state.find_zone(999)
	assert_dict(zone).is_empty()

# --- stage_count / first_empty_stage_slot ---

func test_stage_count_empty() -> void:
	var state := GameState.new()
	assert_int(state.stage_count(0)).is_equal(0)

func test_stage_count_partial() -> void:
	var state := GameState.new()
	state.stages[0][0] = state.create_instance(1)
	state.stages[0][2] = state.create_instance(2)
	assert_int(state.stage_count(0)).is_equal(2)

func test_stage_count_full() -> void:
	var state := GameState.new()
	for i in range(3):
		state.stages[1][i] = state.create_instance(i)
	assert_int(state.stage_count(1)).is_equal(3)

func test_first_empty_stage_slot_empty() -> void:
	var state := GameState.new()
	assert_int(state.first_empty_stage_slot(0)).is_equal(0)

func test_first_empty_stage_slot_partial() -> void:
	var state := GameState.new()
	state.stages[0][0] = state.create_instance(1)
	assert_int(state.first_empty_stage_slot(0)).is_equal(1)

func test_first_empty_stage_slot_full() -> void:
	var state := GameState.new()
	for i in range(3):
		state.stages[0][i] = state.create_instance(i)
	assert_int(state.first_empty_stage_slot(0)).is_equal(-1)

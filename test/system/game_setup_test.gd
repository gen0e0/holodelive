class_name GameSetupTest
extends GdUnitTestSuite

func test_setup_creates_instances() -> void:
	var registry := CardFactory.create_test_registry(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var state := GameSetup.setup_game(registry, rng)
	# 10 instances created
	assert_int(state.instances.size()).is_equal(10)
	assert_int(state.next_instance_id).is_equal(10)

func test_setup_deals_initial_hands() -> void:
	var registry := CardFactory.create_test_registry(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var state := GameSetup.setup_game(registry, rng)
	# Each player gets 2 cards
	assert_int(state.hands[0].size()).is_equal(2)
	assert_int(state.hands[1].size()).is_equal(2)
	# Deck has remaining cards
	assert_int(state.deck.size()).is_equal(6)

func test_setup_total_cards_consistent() -> void:
	var registry := CardFactory.create_test_registry(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state := GameSetup.setup_game(registry, rng)
	var total: int = state.deck.size() + state.hands[0].size() + state.hands[1].size()
	assert_int(total).is_equal(20)

func test_setup_deterministic_with_same_seed() -> void:
	var registry := CardFactory.create_test_registry(10)
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99
	var state1 := GameSetup.setup_game(registry, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99
	var state2 := GameSetup.setup_game(registry, rng2)

	# Same seed → same hands
	assert_array(state1.hands[0]).is_equal(state2.hands[0])
	assert_array(state1.hands[1]).is_equal(state2.hands[1])
	assert_array(state1.deck).is_equal(state2.deck)

func test_setup_small_deck() -> void:
	var registry := CardFactory.create_test_registry(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var state := GameSetup.setup_game(registry, rng)
	# Only 3 cards: p0 gets 2, p1 gets 1, deck empty
	assert_int(state.hands[0].size()).is_equal(2)
	assert_int(state.hands[1].size()).is_equal(1)
	assert_int(state.deck.size()).is_equal(0)

class_name RandomStrategyTest
extends GdUnitTestSuite


var strategy: RandomStrategy


func before_test() -> void:
	strategy = RandomStrategy.new()


# =============================================================================
# pick_action
# =============================================================================

func test_pick_action_empty_returns_empty() -> void:
	var result: Dictionary = strategy.pick_action([], null, null)
	assert_bool(result.is_empty()).is_true()


func test_pick_action_single_returns_that_action() -> void:
	var action: Dictionary = {"type": Enums.ActionType.PASS}
	var result: Dictionary = strategy.pick_action([action], null, null)
	assert_int(result["type"]).is_equal(Enums.ActionType.PASS)


func test_pick_action_multiple_returns_one_of_them() -> void:
	var actions: Array = [
		{"type": Enums.ActionType.PASS},
		{"type": Enums.ActionType.PLAY_CARD, "instance_id": 1, "target": "stage"},
		{"type": Enums.ActionType.PLAY_CARD, "instance_id": 2, "target": "backstage"},
	]
	for i in range(10):
		var result: Dictionary = strategy.pick_action(actions, null, null)
		assert_bool(actions.has(result)).is_true()


# =============================================================================
# pick_choice
# =============================================================================

func test_pick_choice_empty_targets_returns_empty() -> void:
	var choice_data: Dictionary = {"choice_index": 0, "valid_targets": []}
	var result: Dictionary = strategy.pick_choice(choice_data, null, null)
	assert_bool(result.is_empty()).is_true()


func test_pick_choice_no_targets_key_returns_empty() -> void:
	var choice_data: Dictionary = {"choice_index": 0}
	var result: Dictionary = strategy.pick_choice(choice_data, null, null)
	assert_bool(result.is_empty()).is_true()


func test_pick_choice_single_target_returns_it() -> void:
	var choice_data: Dictionary = {"choice_index": 2, "valid_targets": [42]}
	var result: Dictionary = strategy.pick_choice(choice_data, null, null)
	assert_int(result["choice_index"]).is_equal(2)
	assert_int(result["value"]).is_equal(42)


func test_pick_choice_multiple_targets_returns_one() -> void:
	var choice_data: Dictionary = {"choice_index": 1, "valid_targets": [10, 20, 30]}
	var targets: Array = [10, 20, 30]
	for i in range(10):
		var result: Dictionary = strategy.pick_choice(choice_data, null, null)
		assert_int(result["choice_index"]).is_equal(1)
		assert_bool(targets.has(result["value"])).is_true()

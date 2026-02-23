class_name RandomStrategy
extends CpuStrategy

## CPU strategy that picks actions and choices at random.

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()


func pick_action(actions: Array, _state: GameState, _registry: CardRegistry) -> Dictionary:
	if actions.is_empty():
		return {}
	return actions[_rng.randi() % actions.size()]


func pick_choice(choice_data: Dictionary, _state: GameState, _registry: CardRegistry) -> Dictionary:
	var valid_targets: Array = choice_data.get("valid_targets", [])
	if valid_targets.is_empty():
		return {}
	var choice_index: int = choice_data.get("choice_index", 0)
	var value: Variant = valid_targets[_rng.randi() % valid_targets.size()]
	return {"choice_index": choice_index, "value": value}

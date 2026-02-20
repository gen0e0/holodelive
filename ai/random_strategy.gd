class_name RandomStrategy
extends CpuStrategy

## CPU strategy that picks actions and choices at random.


func pick_action(actions: Array, _state: GameState, _registry: CardRegistry) -> Dictionary:
	if actions.is_empty():
		return {}
	return actions[randi() % actions.size()]


func pick_choice(choice_data: Dictionary, _state: GameState, _registry: CardRegistry) -> Dictionary:
	var valid_targets: Array = choice_data.get("valid_targets", [])
	if valid_targets.is_empty():
		return {}
	var choice_index: int = choice_data.get("choice_index", 0)
	var value: Variant = valid_targets[randi() % valid_targets.size()]
	return {"choice_index": choice_index, "value": value}

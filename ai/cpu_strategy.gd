class_name CpuStrategy
extends RefCounted

## Base class for CPU decision-making strategies.
## Subclass and override methods to implement different AI behaviors.


## Pick an action from available actions.
## Returns {} if no action can be chosen.
func pick_action(actions: Array, state: GameState, registry: CardRegistry) -> Dictionary:
	return {}


## Pick a choice from choice_data's valid_targets.
## Returns {"choice_index": ..., "value": ...} or {} if no valid targets.
func pick_choice(choice_data: Dictionary, state: GameState, registry: CardRegistry) -> Dictionary:
	return {}

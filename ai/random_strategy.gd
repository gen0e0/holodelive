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
	var select_max: int = choice_data.get("select_max", 1)

	if select_max <= 1:
		var value: Variant = valid_targets[_rng.randi() % valid_targets.size()]
		return {"choice_index": choice_index, "value": value}

	# 複数選択: select_min 〜 select_max 枚をランダムに選ぶ
	var select_min: int = choice_data.get("select_min", 1)
	var count: int = mini(select_max, valid_targets.size())
	if count < select_min:
		count = mini(select_min, valid_targets.size())
	var shuffled: Array = valid_targets.duplicate()
	_shuffle(shuffled)
	var picked: Array = shuffled.slice(0, count)
	return {"choice_index": choice_index, "value": picked}


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

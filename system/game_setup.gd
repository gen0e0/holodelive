class_name GameSetup
extends RefCounted

## ゲーム初期化: デッキ生成 → シャッフル → 初期手札配布。
## rng を受け取ることで決定論的テストが可能。
static func setup_game(registry: CardRegistry, rng: RandomNumberGenerator = null) -> GameState:
	var state := GameState.new()

	# デッキにカードインスタンスを生成
	var card_ids := registry.get_all_ids()
	for card_id in card_ids:
		var instance_id := state.create_instance(card_id)
		state.deck.append(instance_id)

	# シャッフル
	if rng != null:
		_shuffle_with_rng(state.deck, rng)
	else:
		state.deck.shuffle()

	# 初期手札: 各プレイヤー2枚ドロー
	for _draw in range(2):
		for p in range(2):
			if state.deck.size() > 0:
				var id: int = state.deck.pop_front()
				state.hands[p].append(id)

	return state


## Fisher-Yates シャッフル（決定論的）
static func _shuffle_with_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

extends GdUnitTestSuite

## パッシブスキルの統合テスト。
## GameController 経由で入場時パッシブ・継続型パッシブが正しくトリガーされるかを検証。

var H := SkillTestHelper

var _Skill058: GDScript = load("res://cards/058_kiryu_coco/card_skills.gd")
var _Skill015: GDScript = load("res://cards/015_hoshimachi_suisei/card_skills.gd")


func _create_env_058() -> Dictionary:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(58, "ココ", [], [], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], [], []),
	])
	env.skill_registry.register(58, _Skill058.new())
	return env


func _create_env_015() -> Dictionary:
	var env: Dictionary = H.create_test_env([
		H.make_card_def(15, "すいせい", ["VOCAL"], ["COOL"], [H.passive_skill()]),
		H.make_card_def(99, "OTHER", [], ["HOT"], []),
	])
	env.skill_registry.register(15, _Skill015.new())
	return env


# ===== 058: 入場時パッシブ =====


func test_058_passive_triggers_on_play_card_to_stage() -> void:
	var env: Dictionary = _create_env_058()
	var state: GameState = env.state
	var gc: GameController = env.controller

	# 相手ステージにカードを配置
	var opp_card: int = H.place_on_stage(state, 1, 99)

	# 手札に058を配置してプレイフェーズ
	var inst_id: int = H.place_in_hand(state, 0, 58)
	state.phase = Enums.Phase.PLAY
	state.current_player = 0

	# デッキに最低限のカードを追加（ドロー用）
	for i in range(5):
		H.place_in_deck_top(state, 99)

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "stage"})

	# パッシブが発動: 相手カードは帰宅、自身は除外
	assert_bool(state.home.has(opp_card)).is_true()
	assert_bool(state.removed.has(inst_id)).is_true()


func test_058_passive_does_not_trigger_on_backstage() -> void:
	var env: Dictionary = _create_env_058()
	var state: GameState = env.state
	var gc: GameController = env.controller

	# 相手ステージにカードを配置
	var opp_card: int = H.place_on_stage(state, 1, 99)

	# 手札に058を配置してプレイフェーズ（楽屋が空）
	var inst_id: int = H.place_in_hand(state, 0, 58)
	state.phase = Enums.Phase.PLAY
	state.current_player = 0

	for i in range(5):
		H.place_in_deck_top(state, 99)

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "backstage"})

	# 楽屋はゲスト（face_down）なのでパッシブ不発動
	assert_bool(state.home.has(opp_card)).is_false()
	assert_bool(state.removed.has(inst_id)).is_false()
	assert_int(state.backstages[0]).is_equal(inst_id)


# ===== 015: 継続型パッシブ =====


func test_015_continuous_passive_applied_after_play() -> void:
	var env: Dictionary = _create_env_015()
	var state: GameState = env.state
	var gc: GameController = env.controller

	# ステージに他のカードを配置
	var left: int = H.place_on_stage(state, 0, 99)

	# 手札に015を配置してプレイ
	var inst_id: int = H.place_in_hand(state, 0, 15)
	state.phase = Enums.Phase.PLAY
	state.current_player = 0

	for i in range(5):
		H.place_in_deck_top(state, 99)

	gc.apply_action({"type": Enums.ActionType.PLAY_CARD, "instance_id": inst_id, "target": "stage"})

	# 継続型パッシブにより左のカードに VOCAL Modifier が付与される
	var has_vocal: bool = false
	for mod: Modifier in state.instances[left].modifiers:
		if mod.type == Enums.ModifierType.ICON_ADD and mod.value == "VOCAL":
			has_vocal = true
	assert_bool(has_vocal).is_true()


func test_015_continuous_passive_recalculated_on_adjacency_change() -> void:
	var env: Dictionary = _create_env_015()
	var state: GameState = env.state
	var gc: GameController = env.controller

	# ステージ: [left, 015, right]
	var left: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_stage(state, 0, 15)
	var right: int = H.place_on_stage(state, 0, 99)

	# _recalculate_continuous_passives を直接呼ぶ代わりに、
	# 状態を整えてからOPEN等のアクションを使う。
	# ここでは直接 recalculate を呼ぶため controller の内部メソッドを使う。
	# テスト用に apply_action を通じたフロー全体ではなく、
	# recalculate の正しさを単体で検証する。

	# 最初の計算: 両隣に VOCAL
	gc._recalculate_continuous_passives()

	var left_vocal: bool = false
	var right_vocal: bool = false
	for mod: Modifier in state.instances[left].modifiers:
		if mod.value == "VOCAL":
			left_vocal = true
	for mod: Modifier in state.instances[right].modifiers:
		if mod.value == "VOCAL":
			right_vocal = true
	assert_bool(left_vocal).is_true()
	assert_bool(right_vocal).is_true()

	# left を帰宅させる → 再計算で left の Modifier は消える
	ZoneOps.move_to_home(state, left, DiffRecorder.new())
	gc._recalculate_continuous_passives()

	# left はもう場にいないので Modifier は残っているが意味がない
	# right はまだ隣接しているので VOCAL が付いている
	var right_still_vocal: bool = false
	for mod: Modifier in state.instances[right].modifiers:
		if mod.value == "VOCAL":
			right_still_vocal = true
	assert_bool(right_still_vocal).is_true()

	# left の Modifier はクリアされている（場を離れた際のクリーンアップではなく再計算で消える）
	var left_still_vocal: bool = false
	for mod: Modifier in state.instances[left].modifiers:
		if mod.value == "VOCAL":
			left_still_vocal = true
	assert_bool(left_still_vocal).is_false()


func test_015_continuous_passive_not_applied_when_guest() -> void:
	var env: Dictionary = _create_env_015()
	var state: GameState = env.state
	var gc: GameController = env.controller

	# ステージ: [other]、楽屋に015をゲスト（face_down）として配置
	var other: int = H.place_on_stage(state, 0, 99)
	var inst_id: int = H.place_on_backstage(state, 0, 15)

	gc._recalculate_continuous_passives()

	# ゲスト状態では VOCAL は付与されない
	assert_int(state.instances[other].modifiers.size()).is_equal(0)

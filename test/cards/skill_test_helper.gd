class_name SkillTestHelper
extends RefCounted

## スキルテスト用の共通セットアップ関数群。


## テスト環境を構築する。
## card_defs: Array[CardDef] — テストに必要なカード定義
## 戻り値: {"state": GameState, "registry": CardRegistry, "skill_registry": SkillRegistry, "controller": GameController}
static func create_test_env(card_defs: Array) -> Dictionary:
	var registry := CardRegistry.new()
	var skill_registry := SkillRegistry.new()
	var state := GameState.new()

	for card_def: CardDef in card_defs:
		registry.register(card_def)

	var controller := GameController.new(state, registry, skill_registry)
	return {
		"state": state,
		"registry": registry,
		"skill_registry": skill_registry,
		"controller": controller,
	}


## CardDef を簡易的に作成する。
static func make_card_def(card_id: int, nickname: String = "", icons: Array[String] = [], suits: Array[String] = [], skills: Array = []) -> CardDef:
	return CardDef.new(card_id, nickname, icons, suits, skills)


## play skill メタデータを作成する。
static func play_skill(skill_name: String = "play", description: String = "") -> Dictionary:
	return {"name": skill_name, "type": Enums.SkillType.PLAY, "description": description}


## action skill メタデータを作成する。
static func action_skill(skill_name: String = "action", description: String = "") -> Dictionary:
	return {"name": skill_name, "type": Enums.SkillType.ACTION, "description": description}


## passive skill メタデータを作成する。
static func passive_skill(skill_name: String = "passive", description: String = "") -> Dictionary:
	return {"name": skill_name, "type": Enums.SkillType.PASSIVE, "description": description}


## カードインスタンスを生成してステージに配置する。
static func place_on_stage(state: GameState, player: int, card_id: int) -> int:
	var id: int = state.create_instance(card_id)
	state.stages[player].append(id)
	state.instances[id].face_down = false
	return id


## カードインスタンスを生成して楽屋に配置する。
static func place_on_backstage(state: GameState, player: int, card_id: int) -> int:
	var id: int = state.create_instance(card_id)
	state.backstages[player] = id
	state.instances[id].face_down = true
	return id


## カードインスタンスを生成して手札に配置する。
static func place_in_hand(state: GameState, player: int, card_id: int) -> int:
	var id: int = state.create_instance(card_id)
	state.hands[player].append(id)
	return id


## カードインスタンスを生成してデッキ先頭に配置する。
static func place_in_deck_top(state: GameState, card_id: int) -> int:
	var id: int = state.create_instance(card_id)
	state.deck.push_front(id)
	return id


## カードインスタンスを生成してデッキ末尾に配置する。
static func place_in_deck_bottom(state: GameState, card_id: int) -> int:
	var id: int = state.create_instance(card_id)
	state.deck.append(id)
	return id


## カードインスタンスを生成して自宅に配置する。
static func place_in_home(state: GameState, card_id: int) -> int:
	var id: int = state.create_instance(card_id)
	state.home.append(id)
	return id


## スキルスクリプトを登録する。
static func register_skill(skill_registry: SkillRegistry, card_id: int, skill: BaseCardSkill) -> void:
	skill_registry.register(card_id, skill)

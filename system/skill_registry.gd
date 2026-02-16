class_name SkillRegistry
extends RefCounted

var _skills: Dictionary = {}  # card_id → BaseCardSkill (loaded)
var _paths: Dictionary = {}   # card_id → res:// path (for lazy load)


## テスト用手動登録。
func register(card_id: int, skill: BaseCardSkill) -> void:
	_skills[card_id] = skill


## card_id からスキルスクリプトを取得（遅延ロード）。
func get_skill(card_id: int) -> BaseCardSkill:
	if _skills.has(card_id):
		return _skills[card_id]
	if _paths.has(card_id):
		var script = load(_paths[card_id])
		if script:
			var inst: BaseCardSkill = script.new()
			_skills[card_id] = inst
			return inst
	return null


## card_id のスキルが登録されているか。
func has_skill(card_id: int) -> bool:
	return _skills.has(card_id) or _paths.has(card_id)


## 登録数。
func size() -> int:
	var keys := {}
	for k in _skills:
		keys[k] = true
	for k in _paths:
		keys[k] = true
	return keys.size()


## カードディレクトリからパスを自動構築して登録。
func register_path(card_id: int, path: String) -> void:
	_paths[card_id] = path

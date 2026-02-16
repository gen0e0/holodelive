class_name BaseCardDef
extends RefCounted

func load_card(dir_path: String) -> CardDef:
	var data: CardData = load(dir_path + "/card_data.tres") as CardData
	if data == null:
		return null
	var skills: Array = []
	for s in data.skills:
		skills.append({
			"name": s["name"],
			"type": _parse_skill_type(s["type"]),
			"description": s["description"],
		})
	return CardDef.new(data.card_id, data.nickname,
		data.base_icons, data.base_suits, skills)

static func _parse_skill_type(type_str: String) -> int:
	match type_str:
		"play": return Enums.SkillType.PLAY
		"action": return Enums.SkillType.ACTION
		"passive": return Enums.SkillType.PASSIVE
		_:
			push_warning("Unknown skill type: " + type_str)
			return Enums.SkillType.PLAY

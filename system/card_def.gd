class_name CardDef
extends RefCounted

var card_id: int = 0
var nickname: String = ""
var base_icons: Array[String] = []
var base_suits: Array[String] = []
# skills: Array[SkillDef] — MVP では省略

func _init(p_card_id: int = 0, p_nickname: String = "", p_icons: Array[String] = [], p_suits: Array[String] = []) -> void:
	card_id = p_card_id
	nickname = p_nickname
	base_icons = p_icons
	base_suits = p_suits

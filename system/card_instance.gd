class_name CardInstance
extends RefCounted

var instance_id: int = 0
var card_id: int = 0
var face_down: bool = false
var action_skills_used: Array[int] = []  # 使用済みアクションスキルのインデックス
var modifiers: Array = []  # Array[Modifier]

func _init(p_instance_id: int = 0, p_card_id: int = 0) -> void:
	instance_id = p_instance_id
	card_id = p_card_id


func effective_icons(card_def: CardDef) -> Array[String]:
	var icons: Array[String] = card_def.base_icons.duplicate()
	for mod in modifiers:
		match mod.type:
			Enums.ModifierType.ICON_ADD:
				icons.append(mod.value)
			Enums.ModifierType.ICON_REMOVE:
				var idx := icons.find(mod.value)
				if idx != -1:
					icons.remove_at(idx)
	return icons


func effective_suits(card_def: CardDef) -> Array[String]:
	var suits: Array[String] = card_def.base_suits.duplicate()
	for mod in modifiers:
		match mod.type:
			Enums.ModifierType.SUIT_ADD:
				suits.append(mod.value)
			Enums.ModifierType.SUIT_REMOVE:
				var idx := suits.find(mod.value)
				if idx != -1:
					suits.remove_at(idx)
	return suits

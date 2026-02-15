class_name CardRegistry
extends RefCounted

var _cards: Dictionary = {}  # card_id → CardDef


func register(card_def: CardDef) -> void:
	_cards[card_def.card_id] = card_def


func get_card(card_id: int) -> CardDef:
	return _cards.get(card_id)


func get_all_ids() -> Array:
	return _cards.keys()


func size() -> int:
	return _cards.size()

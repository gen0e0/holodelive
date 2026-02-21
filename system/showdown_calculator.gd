class_name ShowdownCalculator
extends RefCounted

## 各カードから1アイコン・1スートを選択し、最高役を探索する。
## WILD アイコン/スートは任意の値として扱う。

const WILD = "WILD"


## unit: Array of {"icons": Array[String], "suits": Array[String]}
static func evaluate_rank(unit: Array) -> Enums.ShowdownRank:
	if unit.size() < 2:
		return Enums.ShowdownRank.CASUAL

	if _check_miracle(unit):
		return Enums.ShowdownRank.MIRACLE
	if _check_trio(unit):
		return Enums.ShowdownRank.TRIO
	if _check_flash(unit):
		return Enums.ShowdownRank.FLASH
	if _check_duo(unit):
		return Enums.ShowdownRank.DUO

	return Enums.ShowdownRank.CASUAL


static func _can_provide_icon(entry: Dictionary, icon: String) -> bool:
	return icon in entry["icons"] or WILD in entry["icons"]


static func _can_provide_suit(entry: Dictionary, suit: String) -> bool:
	return suit in entry["suits"] or WILD in entry["suits"]


## 同一 (icon, suit) を3+枚が提供可能か
static func _check_miracle(unit: Array) -> bool:
	for icon in Enums.icon_names():
		for suit in Enums.suit_names():
			var count: int = 0
			for entry in unit:
				if _can_provide_icon(entry, icon) and _can_provide_suit(entry, suit):
					count += 1
			if count >= 3:
				return true
	return false


## 同一 icon を3+枚が提供可能か
static func _check_trio(unit: Array) -> bool:
	for icon in Enums.icon_names():
		var count: int = 0
		for entry in unit:
			if _can_provide_icon(entry, icon):
				count += 1
		if count >= 3:
			return true
	return false


## 同一 suit を3+枚が提供可能か
static func _check_flash(unit: Array) -> bool:
	for suit in Enums.suit_names():
		var count: int = 0
		for entry in unit:
			if _can_provide_suit(entry, suit):
				count += 1
		if count >= 3:
			return true
	return false


## 同一 icon を2+枚が提供可能か
static func _check_duo(unit: Array) -> bool:
	for icon in Enums.icon_names():
		var count: int = 0
		for entry in unit:
			if _can_provide_icon(entry, icon):
				count += 1
		if count >= 2:
			return true
	return false


## CardInstance 配列から直接ランクを算出する便利メソッド。
## instances: Array[CardInstance], registry: CardRegistry
static func get_rank(instances: Array, registry: CardRegistry) -> Enums.ShowdownRank:
	var unit: Array = []
	for inst: CardInstance in instances:
		var card_def: CardDef = registry.get_card(inst.card_id)
		if card_def:
			unit.append({"icons": inst.effective_icons(card_def), "suits": inst.effective_suits(card_def)})
	return evaluate_rank(unit)

class_name ShowdownCalculator
extends RefCounted

## ユニット（3〜4枚）のカードデータリストから最高ランクを算出する。
## unit: Array of {"icons": Array[String], "suits": Array[String]}
static func evaluate_rank(unit: Array) -> Enums.ShowdownRank:
	if unit.size() < 2:
		return Enums.ShowdownRank.CASUAL

	# 各アイコンが何枚のカードに出現するかカウント
	var icon_counts: Dictionary = {}
	# 各スートが何枚のカードに出現するかカウント
	var suit_counts: Dictionary = {}
	# 各 (アイコン, スート) ペアが何枚のカードに出現するかカウント
	var pair_counts: Dictionary = {}

	for entry in unit:
		var icons: Array = entry["icons"]
		var suits: Array = entry["suits"]
		for icon: String in icons:
			icon_counts[icon] = icon_counts.get(icon, 0) + 1
			for suit: String in suits:
				var key: String = icon + ":" + suit
				pair_counts[key] = pair_counts.get(key, 0) + 1
		for suit: String in suits:
			suit_counts[suit] = suit_counts.get(suit, 0) + 1

	# ミラクル: 同一アイコン×同一スートが3枚以上
	for key in pair_counts:
		if pair_counts[key] >= 3:
			return Enums.ShowdownRank.MIRACLE

	# トリオ: 同一アイコンが3枚以上
	for icon in icon_counts:
		if icon_counts[icon] >= 3:
			return Enums.ShowdownRank.TRIO

	# フラッシュ: 同一スートが3枚以上
	for suit in suit_counts:
		if suit_counts[suit] >= 3:
			return Enums.ShowdownRank.FLASH

	# デュオ: 同一アイコンが2枚以上
	for icon in icon_counts:
		if icon_counts[icon] >= 2:
			return Enums.ShowdownRank.DUO

	return Enums.ShowdownRank.CASUAL


## CardInstance 配列から直接ランクを算出する便利メソッド。
## instances: Array[CardInstance], registry: CardRegistry
static func get_rank(instances: Array, registry: CardRegistry) -> Enums.ShowdownRank:
	var unit: Array = []
	for inst: CardInstance in instances:
		var card_def: CardDef = registry.get_card(inst.card_id)
		if card_def:
			unit.append({"icons": inst.effective_icons(card_def), "suits": inst.effective_suits(card_def)})
	return evaluate_rank(unit)

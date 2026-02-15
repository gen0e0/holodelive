class_name ShowdownCalculator
extends RefCounted

## ユニット（3〜4枚）のカード定義リストから最高ランクを算出する。
## cards: Array[CardDef] — ユニットを構成するカードの定義
static func evaluate_rank(cards: Array) -> Enums.ShowdownRank:
	if cards.size() < 2:
		return Enums.ShowdownRank.CASUAL

	# 各アイコンが何枚のカードに出現するかカウント
	var icon_counts: Dictionary = {}
	# 各スートが何枚のカードに出現するかカウント
	var suit_counts: Dictionary = {}
	# 各 (アイコン, スート) ペアが何枚のカードに出現するかカウント
	var pair_counts: Dictionary = {}

	for card in cards:
		var card_def: CardDef = card
		for icon in card_def.base_icons:
			icon_counts[icon] = icon_counts.get(icon, 0) + 1
			for suit in card_def.base_suits:
				var key := icon + ":" + suit
				pair_counts[key] = pair_counts.get(key, 0) + 1
		for suit in card_def.base_suits:
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

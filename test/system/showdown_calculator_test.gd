class_name ShowdownCalculatorTest
extends GdUnitTestSuite

## ヘルパー: icons/suits の Dictionary を手軽に作る
func _card(icons: Array[String], suits: Array[String]) -> Dictionary:
	return {"icons": icons, "suits": suits}

# --- ミラクル: 同一アイコン×同一スートが3枚 ---

func test_miracle_3_cards_same_icon_same_suit() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["COOL"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.MIRACLE)

func test_miracle_among_4_cards() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["COOL"]),
		_card(["SEISO"], ["HOT"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.MIRACLE)

func test_miracle_multi_icon_multi_suit() -> void:
	# 各カードが複数アイコン・スートを持ち、SEXY+LOVELY が3枚に共通
	var cards := [
		_card(["VOCAL", "SEXY"], ["COOL", "LOVELY"]),
		_card(["SEXY", "SEISO"], ["LOVELY", "HOT"]),
		_card(["SEXY"], ["LOVELY"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.MIRACLE)

# --- トリオ: 同一アイコンが3枚 ---

func test_trio_3_cards_same_icon_different_suits() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["VOCAL"], ["LOVELY"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.TRIO)

func test_trio_among_4_cards() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["VOCAL"], ["LOVELY"]),
		_card(["SEISO"], ["STAFF"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.TRIO)

# --- フラッシュ: 同一スートが3枚 ---

func test_flash_3_cards_same_suit_different_icons() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["SEISO"], ["COOL"]),
		_card(["SEXY"], ["COOL"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.FLASH)

func test_flash_among_4_cards() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["SEISO"], ["COOL"]),
		_card(["SEXY"], ["COOL"]),
		_card(["ENJOY"], ["HOT"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.FLASH)

# --- トリオはフラッシュより強い ---

func test_trio_beats_flash() -> void:
	# VOCAL が3枚 → トリオ、COOL も3枚にはならない → トリオ優先
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["VOCAL"], ["LOVELY"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.TRIO)

func test_flash_when_no_trio() -> void:
	# スート COOL が3枚揃うがアイコンは全部バラバラ
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["SEISO"], ["COOL"]),
		_card(["ENJOY"], ["COOL"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.FLASH)

# --- デュオ: 同一アイコンが2枚 ---

func test_duo_2_cards_same_icon() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["SEISO"], ["LOVELY"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.DUO)

func test_duo_among_4_cards() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["SEISO"], ["LOVELY"]),
		_card(["ENJOY"], ["STAFF"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.DUO)

# --- カジュアル: 役なし ---

func test_casual_all_different() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["SEISO"], ["HOT"]),
		_card(["ENJOY"], ["LOVELY"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.CASUAL)

func test_casual_4_cards_all_different() -> void:
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["SEISO"], ["HOT"]),
		_card(["ENJOY"], ["LOVELY"]),
		_card(["SEXY"], ["STAFF"]),
	]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.CASUAL)

# --- エッジケース ---

func test_single_card_is_casual() -> void:
	var cards := [_card(["VOCAL"], ["COOL"])]
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.CASUAL)

func test_empty_is_casual() -> void:
	var cards: Array = []
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.CASUAL)

func test_both_trio_and_flash_returns_trio() -> void:
	# 4枚中: VOCAL が3枚(トリオ)、HOT も3枚(フラッシュ) → トリオ優先
	var cards := [
		_card(["VOCAL"], ["HOT"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["SEISO"], ["COOL"]),
	]
	# VOCAL×HOT が3つなのでミラクルになる
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.MIRACLE)

func test_trio_and_flash_separate_sets() -> void:
	# 4枚中: VOCAL が3枚(トリオ)、COOL が別の3枚(フラッシュ)
	# → トリオ優先
	var cards := [
		_card(["VOCAL"], ["COOL"]),
		_card(["VOCAL"], ["HOT"]),
		_card(["VOCAL"], ["LOVELY"]),
		_card(["SEISO"], ["COOL"]),
	]
	# VOCAL は3枚だがスートはバラバラ → トリオ
	# COOL は2枚なのでフラッシュにならない
	assert_int(ShowdownCalculator.evaluate_rank(cards)).is_equal(Enums.ShowdownRank.TRIO)

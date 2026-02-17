class_name CardFactory
extends RefCounted

## テスト用ダミーカードを1枚生成する。
static func create_test_card(card_id: int, nickname: String = "", icons: Array[String] = [], suits: Array[String] = []) -> CardDef:
	if nickname == "":
		nickname = "Card_%d" % card_id
	if icons.is_empty():
		icons = ["VOCAL"] as Array[String]
	if suits.is_empty():
		suits = ["COOL"] as Array[String]
	return CardDef.new(card_id, nickname, icons, suits)


## テスト用レジストリを生成する（指定枚数のダミーカード）。
static func create_test_registry(count: int) -> CardRegistry:
	var registry := CardRegistry.new()
	var icon_pool: Array[String] = Enums.icon_names()
	var suit_pool: Array[String] = Enums.suit_names()
	for i in range(count):
		var icons: Array[String] = [icon_pool[i % icon_pool.size()]]
		var suits: Array[String] = [suit_pool[i % suit_pool.size()]]
		var card := CardDef.new(i, "Card_%d" % i, icons, suits)
		registry.register(card)
	return registry

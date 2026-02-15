class_name CardRegistryTest
extends GdUnitTestSuite

func test_register_and_get() -> void:
	var registry := CardRegistry.new()
	var icons: Array[String] = ["VOCAL"]
	var suits: Array[String] = ["COOL"]
	var card := CardDef.new(1, "Sora", icons, suits)
	registry.register(card)
	assert_int(registry.size()).is_equal(1)
	var fetched := registry.get_card(1)
	assert_str(fetched.nickname).is_equal("Sora")

func test_get_nonexistent() -> void:
	var registry := CardRegistry.new()
	var fetched := registry.get_card(999)
	assert_that(fetched).is_null()

func test_get_all_ids() -> void:
	var registry := CardRegistry.new()
	var icons: Array[String] = ["VOCAL"]
	var suits: Array[String] = ["COOL"]
	registry.register(CardDef.new(10, "A", icons, suits))
	registry.register(CardDef.new(20, "B", icons, suits))
	var ids := registry.get_all_ids()
	assert_int(ids.size()).is_equal(2)
	assert_bool(ids.has(10)).is_true()
	assert_bool(ids.has(20)).is_true()

func test_factory_create_test_card() -> void:
	var card := CardFactory.create_test_card(5, "TestChar")
	assert_int(card.card_id).is_equal(5)
	assert_str(card.nickname).is_equal("TestChar")
	assert_array(card.base_icons).is_not_empty()

func test_factory_create_test_registry() -> void:
	var registry := CardFactory.create_test_registry(10)
	assert_int(registry.size()).is_equal(10)
	var card := registry.get_card(0)
	assert_str(card.nickname).is_equal("Card_0")

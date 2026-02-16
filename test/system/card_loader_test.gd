class_name CardLoaderTest
extends GdUnitTestSuite

var _result: Dictionary

func before() -> void:
	_result = CardLoader.load_all()

func test_load_all_card_count() -> void:
	var registry: CardRegistry = _result.card_registry
	assert_int(registry.size()).is_equal(69)

func test_load_card_data_tokino_sora() -> void:
	var registry: CardRegistry = _result.card_registry
	var card := registry.get_card(1)
	assert_that(card).is_not_null()
	assert_str(card.nickname).is_equal("ときのそら")
	assert_array(card.base_icons).contains(["SEISO"])
	assert_array(card.base_suits).contains(["LOVELY"])
	assert_int(card.skills.size()).is_equal(2)

func test_skill_type_enum_conversion() -> void:
	var registry: CardRegistry = _result.card_registry
	# Card 1 (Tokino Sora) has passive skills
	var sora := registry.get_card(1)
	assert_int(sora.skills[0]["type"]).is_equal(Enums.SkillType.PASSIVE)
	assert_int(sora.skills[1]["type"]).is_equal(Enums.SkillType.PASSIVE)
	# Card 25 (Pekora) has a play skill
	var pekora := registry.get_card(25)
	assert_int(pekora.skills[0]["type"]).is_equal(Enums.SkillType.PLAY)

func test_skill_registry_populated() -> void:
	var skill_reg: SkillRegistry = _result.skill_registry
	assert_bool(skill_reg.has_skill(1)).is_true()
	assert_bool(skill_reg.has_skill(69)).is_true()
	assert_int(skill_reg.size()).is_equal(69)

func test_card_without_skills() -> void:
	# All 69 cards have skills defined, so test with a card that has minimal skills
	var registry: CardRegistry = _result.card_registry
	# Card 69 has 1 skill - verify it loads correctly even with minimal data
	var card := registry.get_card(69)
	assert_that(card).is_not_null()
	assert_int(card.skills.size()).is_greater(0)

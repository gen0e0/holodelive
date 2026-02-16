class_name BaseCardDefTest
extends GdUnitTestSuite

func test_parse_skill_type_play() -> void:
	var result := BaseCardDef._parse_skill_type("play")
	assert_int(result).is_equal(Enums.SkillType.PLAY)

func test_parse_skill_type_action() -> void:
	var result := BaseCardDef._parse_skill_type("action")
	assert_int(result).is_equal(Enums.SkillType.ACTION)

func test_parse_skill_type_passive() -> void:
	var result := BaseCardDef._parse_skill_type("passive")
	assert_int(result).is_equal(Enums.SkillType.PASSIVE)

func test_parse_skill_type_unknown() -> void:
	var result := BaseCardDef._parse_skill_type("unknown_type")
	assert_int(result).is_equal(Enums.SkillType.PLAY)

class_name SkillRegistryTest
extends GdUnitTestSuite


func test_register_and_get() -> void:
	var sr := SkillRegistry.new()
	var skill := BaseCardSkill.new()
	sr.register(1, skill)
	assert_that(sr.get_skill(1)).is_same(skill)


func test_get_nonexistent_returns_null() -> void:
	var sr := SkillRegistry.new()
	assert_that(sr.get_skill(999)).is_null()


func test_has_skill() -> void:
	var sr := SkillRegistry.new()
	assert_bool(sr.has_skill(1)).is_false()
	sr.register(1, BaseCardSkill.new())
	assert_bool(sr.has_skill(1)).is_true()


func test_size() -> void:
	var sr := SkillRegistry.new()
	assert_int(sr.size()).is_equal(0)
	sr.register(1, BaseCardSkill.new())
	sr.register(2, BaseCardSkill.new())
	assert_int(sr.size()).is_equal(2)


func test_lazy_load_from_path() -> void:
	var sr := SkillRegistry.new()
	sr.register_path(1, "res://cards/001_tokino_sora/skills.gd")
	assert_bool(sr.has_skill(1)).is_true()
	var skill := sr.get_skill(1)
	assert_that(skill).is_not_null()
	# 2回目はキャッシュから
	var skill2 := sr.get_skill(1)
	assert_that(skill2).is_same(skill)


func test_size_with_mixed_registration() -> void:
	var sr := SkillRegistry.new()
	sr.register(1, BaseCardSkill.new())
	sr.register_path(2, "res://cards/001_tokino_sora/skills.gd")
	assert_int(sr.size()).is_equal(2)
	# Same card_id in both → counted once
	sr.register_path(1, "res://cards/001_tokino_sora/skills.gd")
	assert_int(sr.size()).is_equal(2)

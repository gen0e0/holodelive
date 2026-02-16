class_name CardLoader
extends RefCounted

static func load_all(cards_dir: String = "res://cards") -> Dictionary:
	var card_registry := CardRegistry.new()
	var skill_registry := SkillRegistry.new()

	var dir := DirAccess.open(cards_dir)
	if dir == null:
		push_error("CardLoader: Cannot open directory: " + cards_dir)
		return {"card_registry": card_registry, "skill_registry": skill_registry}

	dir.list_dir_begin()
	var dir_name := dir.get_next()
	while dir_name != "":
		if dir.current_is_dir() and dir_name != "_base":
			var card_id := _extract_card_id(dir_name)
			if card_id > 0:
				var dir_path := cards_dir + "/" + dir_name
				_load_card_dir(dir_path, card_id, card_registry, skill_registry)
		dir_name = dir.get_next()
	dir.list_dir_end()

	return {"card_registry": card_registry, "skill_registry": skill_registry}

static func _extract_card_id(dir_name: String) -> int:
	var parts := dir_name.split("_", false, 1)
	if parts.size() == 0:
		return -1
	if not parts[0].is_valid_int():
		return -1
	return parts[0].to_int()

static func _load_card_dir(dir_path: String, card_id: int,
		card_registry: CardRegistry, skill_registry: SkillRegistry) -> void:
	var def_script_path := dir_path + "/card_def.gd"
	var def_script: GDScript = load(def_script_path) as GDScript
	if def_script == null:
		push_warning("CardLoader: Cannot load card_def.gd at " + def_script_path)
		return

	var loader: BaseCardDef = def_script.new()
	var card_def: CardDef = loader.load_card(dir_path)
	if card_def == null:
		push_warning("CardLoader: Failed to load card data from " + dir_path)
		return

	card_registry.register(card_def)

	var skills_path := dir_path + "/card_skills.gd"
	if ResourceLoader.exists(skills_path):
		skill_registry.register_path(card_id, skills_path)

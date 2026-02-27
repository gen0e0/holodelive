class_name FieldEffect
extends RefCounted

var type: String = ""              # "skip_action", "no_stage_play", "protection"
var target_player: int = -1        # 影響を受けるプレイヤー
var source_instance_id: int = -1   # 発動元カード (-1 = カード非依存)
var lifetime: int = 1              # 残りターン数 (-1 = ソースカード依存の永続)


func _init(p_type: String = "", p_target: int = -1, p_source: int = -1, p_lifetime: int = 1) -> void:
	type = p_type
	target_player = p_target
	source_instance_id = p_source
	lifetime = p_lifetime


func to_dict() -> Dictionary:
	return {
		"type": type,
		"target_player": target_player,
		"source_instance_id": source_instance_id,
		"lifetime": lifetime,
	}


static func from_dict(d: Dictionary) -> FieldEffect:
	return FieldEffect.new(
		d.get("type", ""),
		d.get("target_player", -1),
		d.get("source_instance_id", -1),
		d.get("lifetime", 1),
	)

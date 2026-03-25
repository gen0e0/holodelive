class_name SkillResult
extends RefCounted

## スキル実行の戻り値。DONE または WAITING_FOR_CHOICE（選択待ち）。
## 選択待ちの場合、choices 配列に1件以上の選択仕様を持つ。
## 同時選択（じゃんけん等）では複数プレイヤー分の選択仕様を同時に持てる。

enum Status { DONE, WAITING_FOR_CHOICE }

var status: Status = Status.DONE
var choices: Array = []  ## Array[Dictionary] — 各要素が1つの choice spec

## 後方互換プロパティ: choices[0] の各フィールドへのショートカット
var choice_type: Enums.ChoiceType:
	get: return choices[0].get("choice_type", Enums.ChoiceType.SELECT_CARD) if not choices.is_empty() else Enums.ChoiceType.SELECT_CARD
var valid_targets: Array:
	get: return choices[0].get("valid_targets", []) if not choices.is_empty() else []
var select_min: int:
	get: return choices[0].get("select_min", 1) if not choices.is_empty() else 1
var select_max: int:
	get: return choices[0].get("select_max", 1) if not choices.is_empty() else 1
var ui_hint: String:
	get: return choices[0].get("ui_hint", "") if not choices.is_empty() else ""
var target_player: int:
	get: return choices[0].get("target_player", -1) if not choices.is_empty() else -1


static func done() -> SkillResult:
	var r := SkillResult.new()
	r.status = Status.DONE
	return r


## 単一プレイヤー向け選択（既存互換）。
## target_player: -1 = 発動者（デフォルト）、0/1 = 指定プレイヤー。
static func waiting(p_choice_type: Enums.ChoiceType, p_valid_targets: Array,
		p_select_min: int = 1, p_select_max: int = 1,
		p_ui_hint: String = "", p_target_player: int = -1) -> SkillResult:
	var r := SkillResult.new()
	r.status = Status.WAITING_FOR_CHOICE
	r.choices = [{
		"target_player": p_target_player,
		"choice_type": p_choice_type,
		"valid_targets": p_valid_targets,
		"select_min": p_select_min,
		"select_max": p_select_max,
		"ui_hint": p_ui_hint,
	}]
	return r


## 複数プレイヤー同時選択。
## 各要素: {"target_player": int, "choice_type": ChoiceType, "valid_targets": Array, ...}
static func waiting_choices(p_choices: Array) -> SkillResult:
	var r := SkillResult.new()
	r.status = Status.WAITING_FOR_CHOICE
	r.choices = p_choices
	return r

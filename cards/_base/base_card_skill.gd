class_name BaseCardSkill
extends RefCounted

## スキルを実行する。
## skill_index: card_def.tres の skills 配列内のインデックス
## ctx: SkillContext（phase, choice_result 等を含む）
## 戻り値: SkillResult
## メソッド名は _skill_0, _skill_1, ... の規約でディスパッチ。
func execute_skill(ctx: SkillContext, skill_index: int) -> SkillResult:
	var method_name := "_skill_%d" % skill_index
	if has_method(method_name):
		var result: SkillResult = call(method_name, ctx)
		return result
	return SkillResult.done()


## カウンター可能かどうかを判定する（パッシブスキル用）。
## オーバーライドして true を返すとカウンター候補になる。
func _can_counter(_ctx: SkillContext) -> bool:
	return false

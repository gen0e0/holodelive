class_name PendingChoice
extends RefCounted

var stack_index: int = -1
var skill_source_instance_id: int = -1
var target_player: int = 0
var choice_type: Enums.ChoiceType = Enums.ChoiceType.SELECT_CARD
var valid_targets: Array = []
var select_min: int = 1   ## 最小選択枚数
var select_max: int = 1   ## 最大選択枚数
var ui_hint: String = ""  ## UI側のハンドラ選択ヒント
var timeout: float = 30.0
var timeout_strategy: String = "first"
var dispatched: bool = false  ## PlayerController に送信済みか
var resolved: bool = false
var result: Variant = null

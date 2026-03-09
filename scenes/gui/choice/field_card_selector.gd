class_name FieldCardSelector
extends ChoiceHandler

## フィールド（ステージ・楽屋）＋自宅カードの選択UI。
## SELECT_CARD タイプの PendingChoice を処理する。
##
## フロー:
##   1. 選択可能カードにグロー表示
##   2. クリックで選択 → カードが少し上に移動
##   3. 規定枚数の選択が揃ったら確定ボタン表示
##   4. 確定ボタンクリックで resolved 発火
##
## CardLayer の selectable / chosen 状態はリフレッシュ後も自動再適用される。

var _card_layer: CardLayer
var _home_view: HomeView
var _get_client_state: Callable  # func() -> ClientState
var _ui_parent: Control          # 確定ボタンを配置する親

var _field_targets: Array = []
var _home_targets: Array = []
var _selected_ids: Array = []    # ユーザーが選択したカード
var _choice_index: int = 0
var _required_count: int = 1     # 1回の PendingChoice で選ぶ枚数
var _active: bool = false
var _confirm_button: OverlayButton = null


func _init(card_layer: CardLayer, home_view: HomeView,
		get_cs: Callable, ui_parent: Control) -> void:
	_card_layer = card_layer
	_home_view = home_view
	_get_client_state = get_cs
	_ui_parent = ui_parent


func can_handle(choice_data: Dictionary) -> bool:
	return choice_data.get("choice_type", -1) == Enums.ChoiceType.SELECT_CARD


func activate(choice_data: Dictionary) -> void:
	_choice_index = choice_data.get("choice_index", 0)
	_required_count = choice_data.get("select_max", 1)
	var select_min: int = choice_data.get("select_min", 1)
	if select_min > _required_count:
		_required_count = select_min
	_selected_ids = []
	var valid_targets: Array = choice_data.get("valid_targets", [])
	var cs: ClientState = _get_client_state.call()
	if cs == null:
		return

	# フィールドカードの対象を抽出
	_field_targets = []
	var field_ids: Array = _get_field_instance_ids(cs)
	for tid in valid_targets:
		if field_ids.has(tid):
			_field_targets.append(tid)

	# 自宅カードの対象を抽出
	_home_targets = []
	for card in cs.home:
		var iid: int = card.get("instance_id", -1)
		if valid_targets.has(iid):
			_home_targets.append(iid)

	_active = true

	if not _field_targets.is_empty():
		_card_layer.set_selectable(_field_targets)

	if not _home_targets.is_empty():
		_home_view.set_selectable(_home_targets)
		_home_view.open_popup()

	_card_layer.card_clicked.connect(_on_field_card_clicked)
	_home_view.card_clicked.connect(_on_home_card_clicked)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	_field_targets = []
	_home_targets = []
	_selected_ids = []
	_card_layer.clear_selectable()
	_card_layer.clear_chosen()
	_home_view.dismiss_popup()
	_remove_confirm_button()
	if _card_layer.card_clicked.is_connected(_on_field_card_clicked):
		_card_layer.card_clicked.disconnect(_on_field_card_clicked)
	if _home_view.card_clicked.is_connected(_on_home_card_clicked):
		_home_view.card_clicked.disconnect(_on_home_card_clicked)


# ---------------------------------------------------------------------------
# クリック処理
# ---------------------------------------------------------------------------

func _on_field_card_clicked(instance_id: int) -> void:
	if not _active:
		return
	if not _field_targets.has(instance_id):
		return
	_toggle_selection(instance_id)


func _on_home_card_clicked(instance_id: int) -> void:
	if not _active:
		return
	if not _home_targets.has(instance_id):
		return
	_toggle_selection(instance_id)


func _toggle_selection(instance_id: int) -> void:
	if _selected_ids.has(instance_id):
		# 選択解除
		_selected_ids.erase(instance_id)
		_set_chosen(instance_id, false)
	else:
		if _selected_ids.size() >= _required_count:
			# 既に規定枚数選択済み → 無視
			return
		_selected_ids.append(instance_id)
		_set_chosen(instance_id, true)
	_update_confirm_button()


func _set_chosen(instance_id: int, chosen: bool) -> void:
	if _home_targets.has(instance_id):
		_home_view.toggle_chosen(instance_id, chosen)
	else:
		_card_layer.toggle_chosen(instance_id, chosen)


# ---------------------------------------------------------------------------
# 確定ボタン
# ---------------------------------------------------------------------------

func _update_confirm_button() -> void:
	if _selected_ids.size() >= _required_count:
		_show_confirm_button()
	else:
		_remove_confirm_button()


func _show_confirm_button() -> void:
	if _confirm_button != null:
		return
	_confirm_button = OverlayButton.create("決定", Rect2(420, 430, 200, 60))
	_confirm_button.visible = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_ui_parent.add_child(_confirm_button)


func _remove_confirm_button() -> void:
	if _confirm_button != null:
		_confirm_button.queue_free()
		_confirm_button = null


func _on_confirm_pressed() -> void:
	if not _active:
		return
	var value: Variant
	if _required_count <= 1:
		value = _selected_ids[0]
	else:
		value = _selected_ids.duplicate()
	resolved.emit(_choice_index, value)


# ---------------------------------------------------------------------------
# ヘルパー
# ---------------------------------------------------------------------------

func _get_field_instance_ids(cs: ClientState) -> Array:
	var ids: Array = []
	for p in range(2):
		for card in cs.stages[p]:
			ids.append(card.get("instance_id", -1))
		if cs.backstages[p] != null:
			ids.append(cs.backstages[p].get("instance_id", -1))
	return ids

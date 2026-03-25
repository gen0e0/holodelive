class_name FieldCardSelector
extends ChoiceHandler

## フィールド（ステージ・楽屋）＋自宅＋手札カードの選択UI。
## SELECT_CARD タイプの PendingChoice を処理する。
##
## フロー:
##   1. 選択可能カードにグロー表示
##   2. クリックで選択 → カードが少し上に移動
##   3. 規定枚数の選択が揃ったら確定ボタン表示
##   4. 確定ボタンクリックで resolved 発火
##
## CardLayer / HomeView / HandZone の状態はリフレッシュ後も自動再適用される。

var _card_layer: CardLayer
var _home_view: HomeView
var _hand_zone: HandZone
var _choice_manager: ChoiceManager
var _get_client_state: Callable  # func() -> ClientState
var _ui_parent: Control          # 確定ボタンを配置する親

var _field_targets: Array = []
var _home_targets: Array = []
var _hand_targets: Array = []
var _selected_ids: Array = []    # ユーザーが選択したカード
var _choice_index: int = 0
var _required_count: int = 1     # 1回の PendingChoice で選ぶ枚数
var _active: bool = false
var _confirm_button: OverlayButton = null
var _zone_buttons: Array = []    # 手札プレイ用ゾーン選択ボタン
var _hand_play_mode: bool = false  # 手札選択 + ゾーン選択の複合モード


func _init(card_layer: CardLayer, home_view: HomeView, hand_zone: HandZone,
		choice_manager: ChoiceManager, get_cs: Callable, ui_parent: Control) -> void:
	_card_layer = card_layer
	_home_view = home_view
	_hand_zone = hand_zone
	_choice_manager = choice_manager
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

	# 手札カードの対象を抽出
	_hand_targets = []
	for card in cs.my_hand:
		var iid: int = card.get("instance_id", -1)
		if valid_targets.has(iid):
			_hand_targets.append(iid)

	# 手札のみ＋1枚選択 → ゾーン選択と複合するモード
	_hand_play_mode = (not _hand_targets.is_empty()
		and _field_targets.is_empty() and _home_targets.is_empty()
		and _required_count == 1)

	_active = true

	if not _field_targets.is_empty():
		_card_layer.set_selectable(_field_targets)

	if not _home_targets.is_empty():
		_home_view.set_selectable(_home_targets)
		_home_view.open_popup()

	if not _hand_targets.is_empty():
		_hand_zone.set_choice_selectable(_hand_targets)

	_card_layer.card_clicked.connect(_on_field_card_clicked)
	_home_view.card_clicked.connect(_on_home_card_clicked)
	_hand_zone.card_clicked.connect(_on_hand_card_clicked)


func auto_resolve(choice_idx: int, value: Variant) -> void:
	# CPU 向け: 選択状態を反映してから resolved を emit
	if value is Array:
		for iid in value:
			if _active:
				_toggle_selection(iid)
	elif value is int and _active:
		_toggle_selection(value)
	resolved.emit(choice_idx, value)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	_field_targets = []
	_home_targets = []
	_hand_targets = []
	_selected_ids = []
	_card_layer.clear_selectable()
	_card_layer.clear_chosen()
	_home_view.dismiss_popup()
	_hand_zone.clear_choice_selectable()
	_hand_zone.clear_chosen()
	_hand_zone.deselect()
	_hand_play_mode = false
	_remove_confirm_button()
	_remove_zone_buttons()
	if _card_layer.card_clicked.is_connected(_on_field_card_clicked):
		_card_layer.card_clicked.disconnect(_on_field_card_clicked)
	if _home_view.card_clicked.is_connected(_on_home_card_clicked):
		_home_view.card_clicked.disconnect(_on_home_card_clicked)
	if _hand_zone.card_clicked.is_connected(_on_hand_card_clicked):
		_hand_zone.card_clicked.disconnect(_on_hand_card_clicked)


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


func _on_hand_card_clicked(instance_id: int) -> void:
	if not _active:
		return
	if not _hand_targets.has(instance_id):
		return
	if _hand_play_mode:
		_on_hand_play_card_clicked(instance_id)
	else:
		_toggle_selection(instance_id)


func _toggle_selection(instance_id: int) -> void:
	if _selected_ids.has(instance_id):
		# 選択解除
		_selected_ids.erase(instance_id)
		_set_chosen(instance_id, false)
	else:
		if _selected_ids.size() >= _required_count:
			# 最古の選択を解除して入れ替え
			var oldest: int = _selected_ids.pop_front()
			_set_chosen(oldest, false)
		_selected_ids.append(instance_id)
		_set_chosen(instance_id, true)
	_update_confirm_button()


func _set_chosen(instance_id: int, chosen: bool) -> void:
	if _hand_targets.has(instance_id):
		_hand_zone.toggle_chosen(instance_id, chosen)
	elif _home_targets.has(instance_id):
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
# 手札プレイモード（カード選択 + ゾーン選択の複合）
# ---------------------------------------------------------------------------

func _on_hand_play_card_clicked(instance_id: int) -> void:
	if _selected_ids.has(instance_id):
		# 同じカード再クリック → 選択解除
		_selected_ids.erase(instance_id)
		_hand_zone.deselect()
		_remove_zone_buttons()
		return
	# 前の選択を解除
	if not _selected_ids.is_empty():
		_selected_ids.clear()
	_selected_ids.append(instance_id)
	# ショーケース表示
	var idx: int = _hand_zone.find_card_index(instance_id)
	_hand_zone.select_card(idx)
	# ゾーンボタン表示
	_show_zone_buttons()


func _show_zone_buttons() -> void:
	_remove_zone_buttons()
	var cs: ClientState = _get_client_state.call()
	if cs == null:
		return
	var p: int = cs.my_player
	var can_stage: bool = cs.stages[p].size() < 3
	var can_backstage: bool = cs.backstages[p] == null
	if can_stage:
		var btn: OverlayButton = OverlayButton.create("ステージにプレイ", Rect2(24, 80, 924, 420))
		btn.visible = true
		btn.pressed.connect(_on_zone_selected.bind("stage"))
		_ui_parent.add_child(btn)
		_zone_buttons.append(btn)
	if can_backstage:
		var btn: OverlayButton = OverlayButton.create("楽屋にプレイ", Rect2(648, 530, 300, 420))
		btn.visible = true
		btn.pressed.connect(_on_zone_selected.bind("backstage"))
		_ui_parent.add_child(btn)
		_zone_buttons.append(btn)


func _remove_zone_buttons() -> void:
	for btn in _zone_buttons:
		btn.queue_free()
	_zone_buttons.clear()


func _on_zone_selected(zone: String) -> void:
	if not _active or _selected_ids.is_empty():
		return
	var card_id: int = _selected_ids[0]
	# 次の SELECT_ZONE を自動応答するようキュー（インデックスは到着時に解決）
	_choice_manager.queue_response(zone)
	# カード選択を submit
	resolved.emit(_choice_index, card_id)


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

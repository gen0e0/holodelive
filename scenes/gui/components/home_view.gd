class_name HomeView
extends Control

## 自宅（ホーム）表示コンポーネント。最上部カードを表向きで表示する。
## 全カードデータを保持し、将来的にブラウズ機能を追加可能。

const _CardViewScene: PackedScene = preload("res://scenes/gui/components/card_view.tscn")
const CARD_SCALE: float = 0.5

var _card_view: CardView
var _cards: Array = []


func _ready() -> void:
	_card_view = _CardViewScene.instantiate()
	_card_view.managed_hover = true
	_card_view.scale = Vector2(CARD_SCALE, CARD_SCALE)
	_card_view.position = -_card_view.pivot_offset * (1.0 - CARD_SCALE)
	add_child(_card_view)


func update_cards(cards: Array) -> void:
	_cards = cards
	if cards.size() > 0:
		var top: Dictionary = cards[cards.size() - 1]
		_card_view.setup(top, true)
		_card_view.visible = true
	else:
		_card_view.visible = false


func get_cards() -> Array:
	return _cards

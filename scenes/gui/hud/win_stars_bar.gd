class_name WinStarsBar
extends HBoxContainer

## 勝利星バー。左に自分の星3つ、右に相手の星3つを中央寄せで配置。
## 自分側: 中央→外（右→左）の順に点灯
## 相手側: 中央→外（左→右）の順に点灯

const WINS_NEEDED: int = 3

var _my_stars: Array[WinStar] = []    # 表示順: 左端(外)→右端(中央寄り)
var _opp_stars: Array[WinStar] = []   # 表示順: 左端(中央寄り)→右端(外)
var _prev_my_wins: int = 0
var _prev_opp_wins: int = 0


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	# 自分の星（左側）: 外→中央の順に並ぶ
	for i in WINS_NEEDED:
		var star := WinStar.new()
		_my_stars.append(star)
		add_child(star)

	# スペーサー
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(260, 0)
	add_child(spacer)

	# 相手の星（右側）: 中央→外の順に並ぶ
	for i in WINS_NEEDED:
		var star := WinStar.new()
		_opp_stars.append(star)
		add_child(star)


func update_wins(my_wins: int, opp_wins: int) -> void:
	var my_changed: bool = my_wins != _prev_my_wins
	var opp_changed: bool = opp_wins != _prev_opp_wins

	# 自分側: 中央から外へ → 配列の右端(index WINS_NEEDED-1)から左へ点灯
	for i in WINS_NEEDED:
		var star_idx: int = WINS_NEEDED - 1 - i
		_my_stars[star_idx].set_active(i < my_wins, my_changed and i == my_wins - 1)

	# 相手側: 中央から外へ → 配列の左端(index 0)から右へ点灯
	for i in WINS_NEEDED:
		_opp_stars[i].set_active(i < opp_wins, opp_changed and i == opp_wins - 1)

	_prev_my_wins = my_wins
	_prev_opp_wins = opp_wins

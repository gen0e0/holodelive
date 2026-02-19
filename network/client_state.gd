class_name ClientState
extends RefCounted

var my_player: int = 0
var my_hand: Array = []            # Array[Dictionary] — {instance_id, card_id, nickname, icons, suits}
var opponent_hand_count: int = 0
var stages: Array = [[], []]       # Array[Array[Dictionary]] — card dict or {instance_id, hidden:true}
var backstages: Array = [null, null]  # null=empty, Dictionary=card info or {instance_id, hidden:true}
var deck_count: int = 0
var home: Array = []               # Array[Dictionary]
var removed: Array = []            # Array[Dictionary]
var current_player: int = 0
var phase: Enums.Phase = Enums.Phase.ACTION
var round_number: int = 1
var turn_number: int = 1
var round_wins: Array[int] = [0, 0]
var live_ready: Array = [false, false]
var live_ready_turn: Array[int] = [-1, -1]


static func from_dict(data: Dictionary) -> ClientState:
	var cs := ClientState.new()
	cs.my_player = data.get("my_player", 0)
	cs.my_hand = data.get("my_hand", [])
	cs.opponent_hand_count = data.get("opponent_hand_count", 0)
	cs.stages = data.get("stages", [[], []])
	cs.backstages = data.get("backstages", [null, null])
	cs.deck_count = data.get("deck_count", 0)
	cs.home = data.get("home", [])
	cs.removed = data.get("removed", [])
	cs.current_player = data.get("current_player", 0)
	cs.phase = data.get("phase", Enums.Phase.ACTION)
	cs.round_number = data.get("round_number", 1)
	cs.turn_number = data.get("turn_number", 1)
	cs.round_wins = data.get("round_wins", [0, 0])
	cs.live_ready = data.get("live_ready", [false, false])
	cs.live_ready_turn = data.get("live_ready_turn", [-1, -1])
	return cs

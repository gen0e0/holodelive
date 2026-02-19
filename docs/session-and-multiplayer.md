# GameSession & マルチプレイ設計

## 目的

現在 UI が `GameController` を直接呼んでいる構造を、**GameSession 抽象層**を介した設計に変更する。
これにより以下を実現する。

- **1人プレイ（CPU対戦）** と **2人対戦（ネットワーク）** を同じ UI コードで動かす
- **イベント駆動の演出**: 状態の差分だけでなく「何が起きたか」をイベント列として UI に渡し、アニメーション再生を可能にする
- **秘匿情報の管理**: 相手の手札・裏向きカードの詳細をクライアントに渡さない

---

## 前提

- **権限モデル**: サーバー権威型（ホスト兼プレイヤー = Listen Server）
- **通信方式**: Godot MultiplayerAPI（ENet ベース RPC）
- **マッチング**: スコープ外（将来課題）
- **既存ロジック層**: `GameState`, `GameController`, `ZoneOps` 等は変更不要

---

## アーキテクチャ全体図

```
Host Machine                              Guest Machine
┌───────────────────────────────┐        ┌─────────────────────────┐
│  NetworkManager (Autoload)    │◄─ENet─►│  NetworkManager         │
│                               │        │                         │
│  GameServer                   │        │                         │
│    ├ GameState                │        │                         │
│    ├ GameController           │        │                         │
│    ├ StateSerializer          │        │                         │
│    └ EventSerializer          │        │                         │
│                               │        │                         │
│  GameClient (子Node)          │        │  GameClient (子Node)    │
│  NetworkGameSession (P0)      │        │  NetworkGameSession (P1)│
│                               │        │                         │
│  UI ── GameSession interface  │        │  UI ── GameSession      │
└───────────────────────────────┘        └─────────────────────────┘

1人プレイ:
┌───────────────────────────────┐
│  LocalGameSession             │
│    ├ GameState                │
│    ├ GameController           │
│    ├ EventSerializer          │
│    └ CpuPlayer (将来)         │
│                               │
│  UI ── GameSession interface  │
└───────────────────────────────┘
```

---

## クラス定義

### GameSession（基底: `session/game_session.gd`）

UI が依存する唯一のインターフェース。

```
class_name GameSession extends RefCounted

# --- UI → Session ---
func start_game() -> void
func send_action(action: Dictionary) -> void
func send_choice(choice_idx: int, value: Variant) -> void

# --- Session → UI (シグナル) ---
signal state_updated(client_state: ClientState, events: Array)
signal actions_received(actions: Array)
signal choice_requested(choice_data: Dictionary)
signal game_started()
signal game_over(winner: int)

# --- 参照 ---
func get_client_state() -> ClientState
func get_available_actions() -> Array
func is_my_turn() -> bool
```

### LocalGameSession（`session/local_game_session.gd`）

ネットワーク不要のローカルセッション。1人プレイ・デバッグ用。

```
class_name LocalGameSession extends GameSession

保持:
  - state: GameState
  - controller: GameController
  - registry: CardRegistry
  - skill_registry: SkillRegistry
  - _last_log_index: int (action_log の読み取り位置)
  - _client_state: ClientState

フロー:
  1. send_action() → controller.apply_action()
  2. action_log から _last_log_index 以降の新規 GameAction を取得
  3. EventSerializer でフィルタ → events 生成
  4. StateSerializer で ClientState 生成
  5. state_updated.emit(client_state, events)
  6. ターン交代判定 → 相手ターンなら CPU 処理 or 同様に emit
```

### NetworkGameSession（`session/network_game_session.gd`）

ネットワーク対戦用。GameClient をラップ。

```
class_name NetworkGameSession extends GameSession

保持:
  - client: GameClient
  - _client_state: ClientState

フロー:
  send_action() → client.send_action() → RPC to server
  client のシグナルを中継して GameSession のシグナルとして emit
```

### GameServer（`network/game_server.gd`）

サーバー権威のゲームロジック。ホストのみに存在。
RPC は直接送受信せず、GameClient の RPC メソッドを経由する。

```
class_name GameServer extends Node

保持:
  - state: GameState
  - controller: GameController
  - registry: CardRegistry
  - skill_registry: SkillRegistry
  - _last_log_index: int
  - _choice_timer: Timer (選択タイムアウト用)

受信 (GameClient 経由):
  - receive_action(action: Dictionary, player_index: int)
  - receive_choice(choice_idx: int, value: int, player_index: int)

処理:
  1. player_index が current_player と一致するか検証
  2. get_available_actions() と照合してバリデーション
  3. apply_action() 実行
  4. action_log から新規 GameAction 取得
  5. 各プレイヤーに対し:
	 a. StateSerializer.serialize_for_player() → filtered state
	 b. EventSerializer.serialize_events() → filtered events
	 c. GameClient の RPC メソッドを rpc_id() で呼び出して送信
  6. 次のアクティブプレイヤーに available_actions を送信

送信 (GameClient の RPC を経由):
  _send_to_player() → GameClient.rpc_id(peer_id, "_on_receive_*", ...)
  GameClient の _on_receive_* は @rpc("authority", "reliable", "call_local")
  なので、ホスト自身のローカル実行も自動的に走る。
```

### GameClient（`network/game_client.gd`）

RPC の送受信を担うプロキシ。ホスト・ゲスト両方に存在。
GameServer → クライアント方向の RPC もすべて GameClient 上のメソッドとして定義。

```
class_name GameClient extends Node

保持:
  - _client_state: ClientState
  - _current_actions: Array

クライアント → サーバー (RPC送信):
  - send_action(action: Dictionary)
	ホスト: _deliver_action() で直接 GameServer.receive_action() を呼ぶ
	ゲスト: _request_action.rpc_id(1, action) → ホスト側 GameClient で受信
  - send_choice(choice_idx: int, value: int)
	同上の分岐

サーバー → クライアント (RPC受信):
  @rpc("authority", "reliable", "call_local")
  - _on_receive_update(state_dict: Dictionary, events: Array)
  - _on_receive_actions(actions: Array)
  - _on_receive_choice(choice_data: Dictionary)
  - _on_receive_game_started()
  - _on_receive_game_over(winner: int)

シグナル:
  - state_updated(client_state: ClientState, events: Array)
  - actions_received(actions: Array)
  - choice_requested(choice_data: Dictionary)
  - game_started()
  - game_over(winner: int)
```

### NetworkManager（`network/network_manager.gd`）

接続ライフサイクル管理。Autoload として登録。`class_name` は持たない。

```
extends Node

メソッド:
  - host_game(port: int = 7000) -> Error  # ENet サーバー作成
  - join_game(address: String, port: int = 7000) -> Error  # クライアント接続
  - disconnect_game()  # 切断・クリーンアップ
  - get_player_index(peer_id: int) -> int
  - get_peer_id_for_player(player_index: int) -> int
  - get_server() -> GameServer
  - get_client() -> GameClient

管理:
  - peer_id → player_index マッピング (ホスト = peer 1 = player 0)
  - 接続状態
  - GameServer / GameClient の生成・破棄

シグナル:
  - player_connected(peer_id: int)
  - player_disconnected(peer_id: int)
  - connection_failed()
  - connection_succeeded()
  - game_ready()  # 2人揃った
```

### StateSerializer（`network/state_serializer.gd`）

GameState をプレイヤーごとにフィルタリングしてシリアライズ。

```
class_name StateSerializer extends RefCounted

static func serialize_for_player(
	state: GameState, player: int, registry: CardRegistry
) -> ClientState

フィルタリングルール (player P が受信する情報):
  hands[P]       → 全情報 (instance_id, card_id, name, icons, suits)
  hands[1-P]     → 枚数のみ
  stages[*]      → 表向き: 全情報 / 裏向き: 存在のみ
  backstage[P]   → 全情報
  backstage[1-P] → 存在・表裏のみ (裏なら詳細非公開)
  deck           → 枚数のみ
  home / removed → 全情報 (公開ゾーン)
  + current_player, phase, round_number, turn_number,
	round_wins, live_ready, live_ready_turn
```

### EventSerializer（`network/event_serializer.gd`）

GameAction 列をプレイヤーごとにフィルタリングしてイベント化。

```
class_name EventSerializer extends RefCounted

static func serialize_events(
	actions: Array,
	for_player: int,
	state: GameState,
	registry: CardRegistry
) -> Array

フィルタリング例:
  DRAW (自分)     → {type: "DRAW", card: {id, name, icons, suits}}
  DRAW (相手)     → {type: "DRAW", card: null}  # 詳細非公開
  PLAY_CARD       → {type: "PLAY_CARD", instance_id, target, card: {...}}
  SKILL_EFFECT    → スキル種別に応じた可視性判定
  ROUND_END       → {type: "ROUND_END", winner}
```

### ClientState（`network/client_state.gd`）

クライアント側が保持するフィルタ済み状態。UI が読む。

```
class_name ClientState extends RefCounted

var my_player: int
var my_hand: Array[Dictionary]
var opponent_hand_count: int
var stages: Array[Array]         # 両プレイヤー分
var backstages: Array            # [Dictionary?, Dictionary?]
var deck_count: int
var home: Array[Dictionary]
var removed: Array[Dictionary]
var current_player: int
var phase: Enums.Phase
var round_number: int
var turn_number: int
var round_wins: Array[int]
var live_ready: Array[bool]
var live_ready_turn: Array[int]

func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> ClientState
```

### ユーティリティクラス

共通ロジックを static メソッドで提供する。

```
utils/display_helper.gd — class_name DisplayHelper extends RefCounted
  static func format_card_dict(d: Dictionary) -> String
  static func format_action(action: Dictionary, cs: ClientState) -> String
  static func format_event(event: Dictionary, cs: ClientState) -> String
  static func lookup_card_label(instance_id: int, cs: ClientState) -> String
  static func get_phase_name(phase: Enums.Phase) -> String

utils/choice_helper.gd — class_name ChoiceHelper extends RefCounted
  static func get_active_pending_choice(pending_choices: Array) -> PendingChoice
  static func make_choice_data(pc: PendingChoice, state: GameState, registry: CardRegistry) -> Dictionary
```

### PendingChoice の選択タイムアウト

```
system/pending_choice.gd:
  var timeout: float = 30.0          # 秒（0以下でタイムアウト無し）
  var timeout_strategy: String = "first"  # "first" / "last" / "random"

GameServer がタイマー管理を担当:
  - _advance() で choice 送信時に Timer を生成・開始
  - タイムアウト時: timeout_strategy に従い valid_targets から自動選択
  - receive_choice() で時間内に応答した場合: タイマーを停止・破棄
  - choice_data に "timeout" フィールドを含めてクライアントに送信（UI カウントダウン用）
```

---

## RPC フロー

```
 GameClient (P0)          GameServer              GameClient (P1)
	  │                       │                        │
	  │                  start_game()                   │
	  │                       │                        │
	  │   GameServer が GameClient._on_receive_* を      │
	  │   rpc_id() で呼び出す（call_local で自身にも配信） │
	  │                       │                        │
	  │◄── update(state,events)│── update(state,events)►│
	  │◄── actions ───────────┤                        │
	  │                       │                        │
	  ├─ send_action ────────►│ (ホスト: 直接呼出し)     │
	  │                  validate & apply               │
	  │◄── update(state,events)│── update(state,events)►│
	  │                       ├─── actions ───────────►│
	  │                       │                        │
	  │                       │◄── _request_action ────┤ (ゲスト: RPC)
	  │                  validate & apply               │
	  │                       │                        │
	  │              [PendingChoice 発生]                │
	  │◄── choice_prompt ────┤                        │
	  ├─── send_choice ─────►│                        │
	  │                  submit_choice & resolve        │
	  │◄── update(state,events)│── update(state,events)►│
```

---

## UI 側の消費パターン

```gdscript
var session: GameSession  # Local or Network — UI は区別しない

func _ready() -> void:
	session.state_updated.connect(_on_state_updated)
	session.actions_received.connect(_on_actions_received)
	session.choice_requested.connect(_on_choice_requested)
	session.game_over.connect(_on_game_over)

func _on_state_updated(client_state: ClientState, events: Array) -> void:
	# イベントを順に再生（各演出の完了を await）
	for event in events:
		await _play_animation(event)
	# 全演出完了後、最終状態で表示を確定
	_refresh_display(client_state)

func _on_actions_received(actions: Array) -> void:
	# 入力受付開始
	_show_action_choices(actions)

func _on_action_selected(action: Dictionary) -> void:
	session.send_action(action)
```

---

## 実装段取り

### Phase A: 基盤クラス（ネットワーク不要） ✅ 完了

ネットワーク無しで動く範囲を先に作り、既存テスト + デバッグ UI で検証する。

| # | タスク | 成果物 |
|---|---|---|
| A-1 | ClientState クラス作成 | `network/client_state.gd` |
| A-2 | StateSerializer 作成 | `network/state_serializer.gd` |
| A-3 | EventSerializer 作成 | `network/event_serializer.gd` |
| A-4 | GameSession 基底クラス作成 | `session/game_session.gd` |
| A-5 | LocalGameSession 作成 | `session/local_game_session.gd` |
| A-6 | テスト: Serializer 単体テスト | `test/network/` |
| A-7 | テスト: LocalGameSession 統合テスト | `test/session/` |
| A-8 | debug_scene を GameSession 経由に書き換え | `scenes/debug/debug_scene.gd` |

### Phase B: ネットワーク層 ✅ 完了

Godot MultiplayerAPI を使ったリモート通信を追加。

| # | タスク | 成果物 |
|---|---|---|
| B-1 | NetworkManager 作成 | `network/network_manager.gd` |
| B-2 | GameServer 作成 | `network/game_server.gd` |
| B-3 | GameClient 作成 | `network/game_client.gd` |
| B-4 | NetworkGameSession 作成 | `session/network_game_session.gd` |
| B-5 | ロビー UI（ホスト/ゲスト選択 + 接続） | `scenes/lobby/` |
| B-6 | 対戦 UI を GameSession で動作させる | `scenes/game/` |
| B-7 | 2プロセスでの動作確認 | 手動テスト |

### Phase C: 堅牢化（将来）

| # | タスク |
|---|---|
| C-1 | 切断時の処理（タイムアウト、自動勝利判定） |
| C-2 | 再接続対応 |
| C-3 | アクションバリデーションの強化 |
| C-4 | CPU プレイヤー（`CpuPlayer`）の実装 |
| C-5 | マッチング機能 |

---

## ファイル配置

```
system/                    # 既存
  ├ game_state.gd
  ├ game_controller.gd
  ├ zone_ops.gd
  ├ pending_choice.gd      # timeout / timeout_strategy フィールド追加
  └ ...

network/                   # Phase A-B で追加
  ├ network_manager.gd     # Autoload (class_name なし)
  ├ game_server.gd
  ├ game_client.gd
  ├ state_serializer.gd
  ├ event_serializer.gd
  └ client_state.gd

session/                   # Phase A-B で追加
  ├ game_session.gd
  ├ local_game_session.gd
  └ network_game_session.gd

utils/                     # 共通ユーティリティ
  ├ display_helper.gd
  └ choice_helper.gd

scenes/
  ├ debug/                 # デバッグ UI (LocalGameSession)
  ├ lobby/                 # ロビー UI (接続管理)
  └ game/                  # ネットワーク対戦 UI (NetworkGameSession)

test/
  ├ network/
  │  ├ state_serializer_test.gd
  │  └ event_serializer_test.gd
  └ session/
	 └ local_game_session_test.gd
```

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
│  NetworkGameSession (P0)      │        │  NetworkGameSession (P1)│
│    └ GameClient               │        │    └ GameClient         │
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
  - event_serializer: EventSerializer
  - my_player: int (人間側の player index)
  - _last_log_index: int (action_log の読み取り位置)

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
  - my_player: int

フロー:
  send_action() → client.send_action() → RPC to server
  client のシグナルを中継して GameSession のシグナルとして emit
```

### GameServer（`network/game_server.gd`）

サーバー権威のゲームロジック。ホストのみに存在。

```
class_name GameServer extends Node

保持:
  - state: GameState
  - controller: GameController
  - registry: CardRegistry
  - skill_registry: SkillRegistry
  - state_serializer: StateSerializer
  - event_serializer: EventSerializer
  - _last_log_index: int
  - _peer_to_player: Dictionary  # {peer_id: player_index}

RPC 受信 (クライアントから):
  @rpc("any_peer", "reliable")
  - request_action(action: Dictionary)
  - request_choice(choice_idx: int, value: Variant)

処理:
  1. 送信元 peer_id → player_index を解決
  2. current_player と一致するか検証
  3. get_available_actions() と照合してバリデーション
  4. apply_action() 実行
  5. action_log から新規 GameAction 取得
  6. 各プレイヤーに対し:
	 a. StateSerializer.serialize_for_player() → filtered state
	 b. EventSerializer.serialize_events() → filtered events
	 c. RPC で送信
  7. 次のアクティブプレイヤーに available_actions を送信

RPC 送信 (クライアントへ):
  @rpc("authority", "reliable", "call_remote") — ゲスト宛
  @rpc("authority", "reliable", "call_local") — ホスト自身宛 (必要に応じて)
  - _client_receive_update(state_dict: Dictionary, events: Array)
  - _client_receive_actions(actions: Array)
  - _client_receive_choice(choice_data: Dictionary)
  - _client_receive_game_over(winner: int)
```

### GameClient（`network/game_client.gd`）

クライアント側のRPCプロキシ。ホスト・ゲスト両方に存在。

```
class_name GameClient extends Node

保持:
  - client_state: ClientState
  - current_actions: Array
  - my_player: int

RPC 送信 (サーバーへ):
  - send_action(action: Dictionary) → rpc_id(1, "request_action", action)
  - send_choice(choice_idx: int, value: Variant) → rpc_id(1, "request_choice", ...)

RPC 受信 (サーバーから):
  @rpc("authority", "reliable")
  - _on_receive_update(state_dict: Dictionary, events: Array)
  - _on_receive_actions(actions: Array)
  - _on_receive_choice(choice_data: Dictionary)
  - _on_receive_game_over(winner: int)

シグナル:
  - state_updated(client_state: ClientState, events: Array)
  - actions_received(actions: Array)
  - choice_requested(choice_data: Dictionary)
  - game_over(winner: int)
```

### NetworkManager（`network/network_manager.gd`）

接続ライフサイクル管理。

```
class_name NetworkManager extends Node

メソッド:
  - create_game(port: int) → ENet サーバー作成
  - join_game(address: String, port: int) → クライアント接続
  - disconnect()

管理:
  - peer_id → player_index マッピング (ホスト = peer 1 = player 0)
  - 接続状態

シグナル:
  - player_connected(player_index: int)
  - player_disconnected(player_index: int)
  - connection_failed()
  - game_ready()  # 2人揃った
```

### StateSerializer（`network/state_serializer.gd`）

GameState をプレイヤーごとにフィルタリングしてシリアライズ。

```
class_name StateSerializer extends RefCounted

static func serialize_for_player(
	state: GameState, player: int, registry: CardRegistry
) -> Dictionary

フィルタリングルール (player P が受信する情報):
  hands[P]       → 全情報 (instance_id, card_id, name, icons, suits)
  hands[1-P]     → 枚数のみ
  stages[*]      → 表向き: 全情報 / 裏向き: 存在のみ
  backstage[P]   → 全情報
  backstage[1-P] → 存在・表裏のみ (裏なら詳細非公開)
  deck           → 枚数のみ
  home / removed → 全情報 (公開ゾーン)
  + current_player, phase, round_number, turn_number,
	round_wins, live_ready
```

### EventSerializer（`network/event_serializer.gd`）

GameAction 列をプレイヤーごとにフィルタリングしてイベント化。

```
class_name EventSerializer extends RefCounted

static func serialize_events(
	actions: Array[GameAction],
	for_player: int,
	registry: CardRegistry
) -> Array[Dictionary]

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

static func from_dict(data: Dictionary) -> ClientState
```

---

## RPC フロー

```
 GameClient (P0)          GameServer              GameClient (P1)
	  │                       │                        │
	  │                  start_game()                   │
	  │◄── update(state,events)│── update(state,events)►│
	  │◄── actions ───────────┤                        │
	  │                       │                        │
	  ├─── request_action ───►│                        │
	  │                  validate & apply               │
	  │◄── update(state,events)│── update(state,events)►│
	  │                       ├─── actions ───────────►│
	  │                       │                        │
	  │                       │◄── request_action ─────┤
	  │                  validate & apply               │
	  │                       │                        │
	  │              [PendingChoice 発生]                │
	  │◄── choice_prompt ────┤                        │
	  ├─── request_choice ──►│                        │
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

### Phase A: 基盤クラス（ネットワーク不要）

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

**検証ポイント**: デバッグ UI が LocalGameSession 経由で動作し、events が正しく生成されること。

### Phase B: ネットワーク層

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

**検証ポイント**: 2つの Godot インスタンスで対戦が完走すること。

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
system/                    # 既存 — 変更なし
  ├ game_state.gd
  ├ game_controller.gd
  ├ zone_ops.gd
  └ ...

network/                   # 新規
  ├ network_manager.gd
  ├ game_server.gd
  ├ game_client.gd
  ├ state_serializer.gd
  ├ event_serializer.gd
  └ client_state.gd

session/                   # 新規
  ├ game_session.gd
  ├ local_game_session.gd
  └ network_game_session.gd

test/
  ├ network/               # 新規
  │  ├ state_serializer_test.gd
  │  └ event_serializer_test.gd
  └ session/               # 新規
	 └ local_game_session_test.gd
```

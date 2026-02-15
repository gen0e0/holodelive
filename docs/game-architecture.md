# HOLOdeLIVE ゲームアーキテクチャ

## 設計方針

- GameState は RefCounted を継承したピュアなデータクラス
- カードの「定義（静的）」と「個体（実行時）」を完全に分離する
- 全ての状態変更を差分（Diff）として記録し、履歴の再生・巻き戻しを可能にする
- スキルによるバフ/デバフは保存型（Modifier）で管理し、イベントフックでライフサイクルを制御する
- スキルの解決はスタック構造で管理し、割り込み・カウンターに対応する
- GameState（データ）と GameController（ロジック）を分離する

---

## データモデル

### CardDef（静的定義・不変）

カードのマスターデータ。データファイルから読み込まれ、ゲーム中に変化しない。

```
CardDef
├── card_id: int              # カード定義の一意ID
├── nickname: String          # キャラクター名
├── base_icons: Array[String] # 基本アイコン（例: VOCAL, SEXY）
├── base_suits: Array[String] # 基本スート（例: COOL, HOT）
├── skills: Array[SkillDef]   # スキル定義（Play / Action / Passive）
```

### CardInstance（実行時の個体）

場に存在するカードの個体。同一の CardDef から複数のインスタンスが生成されうる（複製スキル等）。

```
CardInstance
├── instance_id: int              # ゲーム内で一意（自動採番）
├── card_id: int                  # 参照先の CardDef
├── face_down: bool               # 裏向きかどうか
├── action_skills_used: Array[int] # このターンに使用済みのアクションスキルのインデックス（ターン毎リセット）
├── modifiers: Array[Modifier]    # 適用中のバフ/デバフ
```

#### 実効値の算出

```
effective_icons = CardDef.base_icons + modifiers による加減算
effective_suits = CardDef.base_suits + modifiers による加減算
```

パッシブスキルによる動的な効果も、Modifier として保存する（算出型は採用しない）。

### Modifier（効果の記録）

カードに付与されたバフ/デバフの個別記録。

```
Modifier
├── type: ModifierType            # ICON_ADD / ICON_REMOVE / SUIT_ADD / SUIT_REMOVE / ...
├── value: String                 # 対象のアイコンやスート名
├── source_instance_id: int       # この効果を付与したカードの instance_id
├── persistent: bool              # true: ソースが場を離れても残る / false: ソース離脱時に除去
```

#### イベントフック: ソース離脱時のクリーンアップ

カードインスタンスがゾーンを離脱した時：

1. 離脱するインスタンスの `instance_id` を取得
2. 全 CardInstance の `modifiers` を走査
3. `source_instance_id` が一致 かつ `persistent == false` の Modifier を除去

---

## GameState 構造

```
GameState extends RefCounted
│
├── # インスタンス管理
├── next_instance_id: int                          # 採番カウンタ
├── instances: Dictionary[int, CardInstance]        # instance_id → CardInstance
│
├── # ゾーン（全て instance_id を格納）
├── deck: Array[int]                               # ドロー元
├── hands: [Array[int], Array[int]]                # 各プレイヤーの手札
├── stages: [[int, int, int], [int, int, int]]     # 各プレイヤーのステージ（3スロット、空=-1）
├── backstages: [int, int]                         # 各プレイヤーの楽屋（空=-1）
├── home: Array[int]                               # 共有、到着順
├── removed: Array[int]                            # ゲームから除外済み
│
├── # ゲーム進行
├── current_player: int                            # 0 or 1
├── phase: Phase                                   # ACTION / PLAY / LIVE / SHOWDOWN
├── round_number: int
├── turn_number: int
├── round_wins: [int, int]                         # 各プレイヤーのラウンド勝利数
├── live_ready: [bool, bool]
├── live_ready_turn: [int, int]                    # ライブ準備になったターン番号（同ランク時の判定用）
│
├── # スキル解決スタック
├── skill_stack: Array[SkillStackEntry]            # LIFO スタック
│
├── # スキル解決中のプレイヤー選択待ち（スキル専用）
├── pending_choices: Array[PendingChoice]           # 0〜2件
│
├── # 履歴
├── action_log: Array[GameAction]                  # 全アクションの記録
```

---

## スキル解決スタック

スキルの割り込み・カウンターに対応する LIFO（後入れ先出し）構造。

### SkillStackEntry

```
SkillStackEntry
├── skill_ref: SkillDef               # 発動するスキルの定義
├── source_instance_id: int           # 発動元カードの instance_id
├── player: int                       # 発動したプレイヤー
├── targets: Array                    # 対象（選択済みの場合）
├── state: SkillState                 # PENDING / RESOLVING / RESOLVED / COUNTERED
```

### 解決フロー

```
1. プレイヤーAがスキルXを発動
   → SkillStackEntry(X) を push

2. トリガーチェック
   → 全カードのパッシブスキルを走査
   → 「相手スキル発動時」条件に合致するカードがあるか？

3. プレイヤーBがカウンタースキルYの発動を選択
   → SkillStackEntry(Y) を push（Xの上に積まれる）

4. 再びトリガーチェック（カウンター返しの可能性）
   → なければ解決開始

5. スタック上から順に解決（LIFO）
   ① Y を解決 → X を COUNTERED に
   ② X は COUNTERED なので効果なし

※ Yがスルーされた場合:
   ① X を解決 → 通常通り効果適用
```

### カウンター判定でのプレイヤー選択

トリガーチェック時、カウンター可能なパッシブスキルが見つかった場合、そのプレイヤーに「カウンターするか / スルーするか」の選択が `pending_choices` を通じて提示される。

---

## PendingChoice（スキル解決中の選択待ち）

**スキル解決専用**。フェーズにおけるプレイヤーの行動選択（どのカードを使うか、パスするか等）は GameController が状態から算出するため、ここには含まない。

同時に最大2件（両プレイヤー同時選択）が発生しうる。全件が解決されるまでスキル処理は中断される。

```
PendingChoice
├── stack_index: int                  # 対応する SkillStackEntry のインデックス
├── skill_source_instance_id: int     # スキルを発動したカードの instance_id
├── target_player: int                # 選択を求められているプレイヤー
├── choice_type: ChoiceType           # SELECT_CARD / SELECT_ZONE / ...
├── valid_targets: Array              # 選択可能な対象のリスト
├── resolved: bool                    # 選択済みかどうか
├── result: Variant                   # 選択結果（解決後に格納）
```

---

## GameController（ロジック層）

GameState とは別のクラス。ゲームフローの進行とプレイヤー行動の算出を担当する。

```
GameController
├── state: GameState
│
├── # フェーズにおけるプレイヤー行動の算出
├── get_available_actions(state) → Array[PlayerAction]
│   # phase + 盤面から、今そのプレイヤーが取れる行動を一覧化
│   # ACTION フェーズ: [ActivateSkill(card_A), Open(backstage), Pass]
│   # PLAY フェーズ:   [PlayCard(card_X, stage_0), PlayCard(card_X, backstage)]
│
├── # アクション適用
├── apply_action(action: PlayerAction) → void
│   # 状態変更を StateDiff として記録しつつ GameState を更新
│   # スキル発動時は skill_stack に push しトリガーチェック
│
├── # スキルスタック解決
├── resolve_skill_stack() → void
│   # スタックを上から順に解決、各段階でトリガーチェック
│   # PendingChoice が発生したら中断、選択後に再開
```

### 役割分担まとめ

| 責務 | 担当 |
|---|---|
| データ保持 | GameState |
| フェーズの選択肢算出 | GameController.get_available_actions() |
| スキル中の選択肢提示 | GameState.pending_choices |
| 状態変更の適用 | GameController.apply_action() |
| スキル解決・スタック管理 | GameController.resolve_skill_stack() |
| 全決定の記録 | GameState.action_log |

---

## 差分履歴システム

### GameAction（プレイヤー行動の記録）

1つのプレイヤー行動を表し、それによって発生した全ての状態変更（Diff）を束ねる。フェーズの行動もスキルの効果も、全て GameAction として記録される。

```
GameAction extends RefCounted
├── type: ActionType       # DRAW / PLAY_CARD / OPEN / ACTIVATE_SKILL / SKILL_EFFECT / ...
├── player: int            # 行動したプレイヤー
├── params: Dictionary     # 行動固有のパラメータ（対象カード、選択結果など）
├── diffs: Array[StateDiff]  # この行動で発生した全ての原子的状態変更
```

### StateDiff（原子的状態変更）

状態の最小変更単位。巻き戻しは diffs を逆順に逆適用する。

```
StateDiff extends RefCounted
├── type: DiffType
├── details: Dictionary    # 変更内容の詳細（下記参照）
```

#### DiffType 一覧

| DiffType | details の内容 |
|---|---|
| `CARD_MOVE` | `instance_id`, `from_zone`, `from_index`, `to_zone`, `to_index` |
| `CARD_FLIP` | `instance_id`, `before: bool`, `after: bool` |
| `MODIFIER_ADD` | `instance_id`, `modifier: Modifier` |
| `MODIFIER_REMOVE` | `instance_id`, `modifier: Modifier` |
| `PROPERTY_CHANGE` | `property_name`, `before: Variant`, `after: Variant` |
| `INSTANCE_CREATE` | `instance_id`, `card_id` |
| `INSTANCE_DESTROY` | `instance_id`, `card_id` |

---

## 列挙型

```
enum Phase { ACTION, PLAY, LIVE, SHOWDOWN }

enum ActionType { DRAW, PLAY_CARD, OPEN, ACTIVATE_SKILL, SKILL_EFFECT, TURN_START, TURN_END, ROUND_START, ROUND_END }

enum DiffType { CARD_MOVE, CARD_FLIP, MODIFIER_ADD, MODIFIER_REMOVE, PROPERTY_CHANGE, INSTANCE_CREATE, INSTANCE_DESTROY }

enum ModifierType { ICON_ADD, ICON_REMOVE, SUIT_ADD, SUIT_REMOVE }

enum ChoiceType { SELECT_CARD, SELECT_ZONE }

enum SkillState { PENDING, RESOLVING, RESOLVED, COUNTERED }
```

---

## 設計上の注意点

### カードスキルの実装

- 約60枚の全カードが固有スキルを持つため、各カード・各スキルに個別のコードが必要
- スキル発動時は skill_stack に push し、トリガーチェックを経て LIFO 順に解決する
- スキル解決中にプレイヤーの入力待ちが発生する場合、`pending_choices` をセットしてスタック解決を中断し、選択を受け取ったら続行する
- スキルが生成する状態変更は全て StateDiff として記録され、GameAction に束ねられる

### インスタンス管理

- ゲーム開始時、デッキの各カードに対して CardInstance を生成し、instance_id を採番する
- カード複製スキルにより、同一 card_id から複数の CardInstance が存在しうる
- ゲームから除外されたインスタンスも `instances` Dictionary には残す（履歴参照用）

### GameState のクローン

- `duplicate()` メソッドを実装し、デバッグ・テスト・AI思考用にスナップショットを取得可能にする

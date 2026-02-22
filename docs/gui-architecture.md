# GUI アーキテクチャ設計

## 基本方針

- **2D Control ベース**の画面構成
- 固定解像度 **1920x1080**、`stretch_mode = canvas_items`
- GameSession のシグナルを受けてビューを更新する **MVC 的な分離**
- カード演出（移動アニメ、浮遊、パーティクル等）のために、レイアウト管理とカードノードの親子関係を分離

---

## ディレクトリ構成

```
scenes/
├── app/                          ← 既存: アプリルート
├── lobby/                        ← 既存: ロビー
├── debug/                        ← 既存: テキストベースデバッグ画面
├── game/                         ← 既存: ネットワーク対戦画面（テキスト）
│
└── gui/                          ← 新規: GUI ゲーム画面
    ├── game_screen.tscn          ← ルートシーン
    ├── game_screen.gd            ← GameSession 接続、子への配分
    │
    ├── components/               ← 再利用コンポーネント
    │   ├── card_view.tscn        ← カード1枚の表示
    │   ├── card_view.gd
    │   ├── slot_marker.tscn      ← レイアウト用の空スロット
    │   ├── slot_marker.gd
    │   ├── slot_highlight.tscn   ← ドロップ先候補のハイライト
    │   ├── slot_highlight.gd
    │   ├── speech_bubble.tscn    ← カード追従セリフ吹き出し
    │   └── speech_bubble.gd
    │
    ├── field/                    ← 盤面レイアウト
    │   ├── field_layout.tscn     ← SlotMarker の配置・座標管理
    │   ├── field_layout.gd
    │   ├── card_layer.tscn       ← 全 CardView のフラットな親
    │   └── card_layer.gd         ← CardView の生成・破棄・移動アニメ
    │
    ├── hud/                      ← 情報表示・操作 UI
    │   ├── top_bar.tscn          ← ラウンド・ターン・フェーズ・勝利数
    │   ├── top_bar.gd
    │   ├── action_panel.tscn     ← Pass / 補助ボタン
    │   ├── action_panel.gd
    │   ├── log_panel.tscn        ← トグル式イベントログ
    │   └── log_panel.gd
    │
    ├── overlay/                  ← 選択 UI・モーダル
    │   ├── card_detail.tscn      ← カード詳細ポップアップ
    │   ├── card_detail.gd
    │   ├── zone_select.tscn      ← ステージ / 楽屋 選択オーバーレイ
    │   ├── zone_select.gd
    │   ├── home_browser.tscn     ← 自宅カード一覧（選択時）
    │   └── home_browser.gd
    │
    ├── skill_ui/                 ← スキル固有の演出シーン
    │   ├── dice_scene.tscn       ← 020 等: ダイス演出
    │   ├── dice_scene.gd
    │   ├── janken_scene.tscn     ← 059: じゃんけんミニゲーム
    │   ├── janken_scene.gd
    │   ├── random_pick.tscn      ← 010/036/056: ランダム選出演出
    │   └── random_pick.gd
    │
    ├── effect/                   ← エフェクト
    │   ├── effect_layer.tscn     ← カード非追従の全画面エフェクト
    │   └── effect_layer.gd
    │
    └── manager/                  ← 入力・状態管理
        ├── input_manager.gd      ← 入力モード管理、選択状態の制御
        └── animation_queue.gd    ← アニメーション順序管理
```

---

## シーンツリー

```
GameScreen (Control)
│
├── Background (TextureRect)
│
├── TopBar (top_bar.tscn)
│
├── FieldLayout (field_layout.tscn)
│   ├── OpponentHandSlots              ← 動的: SlotMarker × opponent_hand_count
│   ├── OpponentStageSlots             ← 固定: SlotMarker × 3
│   ├── OpponentBackstageSlot          ← 固定: SlotMarker × 1
│   ├── DeckSlot                       ← 固定: SlotMarker × 1
│   ├── HomeSlot                       ← 固定: SlotMarker × 1
│   ├── PlayerStageSlots               ← 固定: SlotMarker × 3
│   ├── PlayerBackstageSlot            ← 固定: SlotMarker × 1
│   └── PlayerHandSlots               ← 動的: SlotMarker × hand.size()
│
├── CardLayer (card_layer.tscn)        ← 全 CardView がフラットに存在
│   └── CardView × N
│
├── SlotHighlightLayer (Control)       ← ドロップ先候補のハイライト表示
│   └── SlotHighlight × N
│
├── EffectLayer (effect_layer.tscn)
│
├── OverlayLayer (Control)             ← モーダル UI の親
│   ├── (CardDetail)                   ← 必要時に表示
│   ├── (ZoneSelect)                   ← 必要時に表示
│   ├── (HomeBrowser)                  ← 必要時に表示
│   └── (SkillUI)                      ← 必要時に表示 (dice, janken 等)
│
├── ActionPanel (action_panel.tscn)
│
└── LogPanel (log_panel.tscn)
```

---

## CardView

カード1枚を表示する再利用コンポーネント。CardLayer の直下にフラット配置され、自由に座標移動可能。

```
CardView (Control)
├── Shadow (Sprite2D)                   ← 浮遊時の落ち影
├── CardBody (Control)                  ← スケール・回転の対象
│   ├── CardTexture (TextureRect)       ← カード画像 / 裏面
│   ├── IconsRow (HBoxContainer)        ← アイコンバッジ列
│   ├── SuitsRow (HBoxContainer)        ← スートバッジ列
│   ├── NicknameLabel (Label)           ← キャラ名
│   ├── HighlightOverlay (ColorRect)    ← 選択可能 / 選択中ハイライト
│   └── SkillIndicator (TextureRect)    ← スキル種別マーク
├── SpeechBubble (speech_bubble.tscn)   ← セリフ吹き出し（通常非表示）
└── ParticleAnchor (Node2D)             ← カード追従パーティクル
```

### CardView の状態

| 状態 | 表示 |
|---|---|
| 表向き | カード情報を全表示 |
| 裏向き | CardBack テクスチャのみ |
| 空スロット | SlotMarker で位置だけ示す（CardView は存在しない） |
| 選択可能 | HighlightOverlay 点灯、クリック受付 |
| 選択中 | 強調ハイライト + 浮遊演出 |

### CardView の生成・破棄

- ゾーンに登場するたびに CardLayer に生成、退場時に破棄
- 相手の手札は `opponent_hand_count` のみ既知 → 裏向き CardView を枚数分生成
- 秘匿情報の漏洩を防ぐため、非公開カードのインスタンスを事前生成しない

---

## 入力モデル

### InputManager

現在の入力モードを管理し、CardView / SlotHighlight への選択可否を制御する。

| モード | トリガー | 操作 |
|---|---|---|
| IDLE | デフォルト | カードクリックで詳細表示 |
| SELECT_ACTION | actions_received | 手札クリック → プレイ先選択へ遷移。ステージカードクリック → スキル発動 |
| SELECT_PLAY_TARGET | 手札選択後 | SlotHighlight（ステージ空き / 楽屋）をクリックで確定 |
| SELECT_CARD | choice_requested (SELECT_CARD) | 対象カードをハイライト、クリックで選択 |
| SELECT_ZONE | choice_requested (SELECT_ZONE) | ZoneSelect オーバーレイ表示 |
| SKILL_UI | スキル固有 UI 表示中 | モーダルに入力を委譲 |

### 操作フロー例: カードをステージにプレイ

```
actions_received → InputManager: SELECT_ACTION モード
  ↓
手札の CardView クリック
  ↓
InputManager: SELECT_PLAY_TARGET モードへ遷移
SlotHighlightLayer: ステージ空きスロット + 楽屋を強調
  ↓
SlotHighlight クリック（例: ステージ slot 0）
  ↓
InputManager → GameScreen.send_action({type: PLAY_CARD, instance_id, target: "stage"})
CardLayer: 手札位置 → ステージ位置への移動アニメ開始
  ↓
state_updated → FieldLayout: SlotMarker 更新
```

---

## アニメーション管理

### AnimationQueue

状態更新のイベントを受け取り、アニメーションを順序実行する。

- `state_updated` で受け取ったイベント列を AnimationQueue に積む
- 各イベント（ドロー、プレイ、帰宅等）に対応するアニメーションを順次再生
- アニメーション完了後に次のイベントを処理
- 全イベント消化後に入力を受け付ける

これにより「ドロー → カード移動 → スキル発動ログ → 効果適用」が自然な順番でプレイヤーに見える。

---

## スキル固有 UI

通常の PendingChoice（カード選択 / ゾーン選択）では表現できないスキルに対して、専用シーンをモーダル表示する。

### 対象スキル

| シーン | 対象カード | 内容 |
|---|---|---|
| dice_scene | 020 猫又おかゆ | ダイス勝負演出 |
| janken_scene | 059 ぺこらマミー | じゃんけん3回 |
| random_pick | 010, 036, 056 | ランダム選出カードの演出 |

### 呼び出し方

1. `choice_requested` で `RANDOM_RESULT` 等を受信
2. InputManager がスキル種別を判定し、対応するシーンを OverlayLayer にインスタンス化
3. スキル UI が演出を再生し、結果を `completed` シグナルで返す
4. InputManager が `send_choice()` を呼び出す

将来スキルが追加された場合は、`skill_ui/` にシーンを追加するだけで拡張可能。

---

## レイヤー順序（下から上）

| 順序 | ノード | 役割 |
|---|---|---|
| 0 | Background | 背景 |
| 1 | TopBar | 情報表示 |
| 2 | FieldLayout | SlotMarker（不可視、レイアウト計算用） |
| 3 | CardLayer | カード描画 |
| 4 | SlotHighlightLayer | ドロップ先ハイライト |
| 5 | EffectLayer | 全画面エフェクト |
| 6 | OverlayLayer | モーダル UI（詳細、選択、スキル UI） |
| 7 | ActionPanel | 操作ボタン |
| 8 | LogPanel | ログ |

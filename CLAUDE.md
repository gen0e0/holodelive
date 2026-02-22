# HOLOdeLIVE

2人専用ターン制カードゲーム。

## プロジェクト構成

- `docs/game-rules.md` - ゲームルール詳細
- `docs/game-architecture.md` - データ構造・アーキテクチャ設計
- `docs/session-and-multiplayer.md` - GameSession & マルチプレイ設計
- `test/` - ユニットテスト（GdUnit4）
- `addons/gdUnit4/` - テストフレームワーク

## テスト

- フレームワーク: [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) v6.1.1
- テストファイルは `test/` 以下に、テスト対象と対応するディレクトリ構造で配置する
  - 例: `system/game_state.gd` → `test/system/game_state_test.gd`
- テストクラスは `GdUnitTestSuite` を継承し、テストメソッドは `test_` プレフィックスを付ける
- CLI実行: `GODOT_BIN=/usr/local/bin/godot ./addons/gdUnit4/runtest.sh -a test/`
- 全テスト実行時は `... 2>&1 | grep FAILED` で失敗だけ抽出する（出力が空なら全パス）
- 失敗があればそのファイルだけ再実行して詳細を確認: `GODOT_BIN=/usr/local/bin/godot ./addons/gdUnit4/runtest.sh -a test/path/to/failing_test.gd`
- XML/HTML レポートはトークン消費が大きいので読まない
- 新しい `class_name` を持つファイルを追加・削除した後は、テスト前にクラスキャッシュの再構築が必要:
  - `godot --headless --editor --quit`
  - `--headless --quit` だけでは `global_script_class_cache.cfg` が更新されないので注意
- 新規コード追加時は対応するテストも作成すること

## コーディング規約

### 変数宣言: `:=` 推論を避け、型を明示する

GDScript の `:=` は型なし `Array` / `Dictionary` のメソッド戻り値（`.duplicate()`, `.find()`, `.size()` 等）で `Variant` 推論エラーを起こしやすい。**原則として型を明示宣言する。**

```gdscript
# Good
var ids: Array = state.stages[p].duplicate()
var idx: int = deck.find(instance_id)
var count: int = hands[p].size()

# Bad — Variant 推論エラーの原因
var ids := state.stages[p].duplicate()
var idx := deck.find(instance_id)
```

`:=` を使ってよいケース: 右辺の型が明確なリテラル・コンストラクタ・型付きメソッド呼び出し。
```gdscript
var state := GameState.new()      # OK: コンストラクタ
var name := "test"                # OK: String リテラル
var count := 0                    # OK: int リテラル
```

## 設計上の重要事項

### カード設計: CardDef / CardInstance の分離

- **CardDef**: 静的なマスターデータ（名前、基本アイコン、基本スート、スキル定義）
- **CardInstance**: 実行時の個体（instance_id で一意識別）。バフ/デバフを Modifier として保存
- 複製スキルにより同一 card_id から複数インスタンスが存在しうるため、ゾーンには instance_id を格納
- 実効値 = 基本値 + Modifier による加減算

### Modifier とイベントフック

- バフ/デバフは保存型（Modifier オブジェクト）で管理
- 各 Modifier は `source_instance_id` と `persistent` フラグを持つ
- カードがゾーンを離脱した時、非永続 Modifier を自動クリーンアップ

### スキル解決スタック

- スキルの割り込み・カウンターに対応する LIFO（後入れ先出し）構造
- スキル発動 → トリガーチェック → カウンター可否の選択 → LIFO 順に解決
- PendingChoice はスキル解決専用。フェーズの行動選択は GameController が算出

### GameState / GameController の分離

- GameState: ピュアなデータ（状態保持のみ）
- GameController: ロジック層（行動算出、アクション適用、スキルスタック解決）

### 差分履歴

- 全ての状態変更を StateDiff（原子的変更）として記録
- GameAction が複数の StateDiff を束ね、プレイヤー行動の単位を形成
- 巻き戻し = diffs の逆順逆適用

### カードスキルのアーキテクチャ

- 約60枚の全カードがそれぞれユニークなスキルを持つ
- カードごとに固有のスキルコードが必要（共通化不可）
- スキル解決中にプレイヤーの入力待ち（選択）が発生しうる → PendingChoice で中断/再開
- スキルは3種類: Play Skill, Action Skill, Passive Skill

### ゲームフロー

- ターン制: ドロー → アクションフェーズ → プレイフェーズ → ターン終了チェック
- ライブ準備 → ショウダウンによるラウンド勝敗決定
- ラウンド勝利を規定数積み重ねてゲーム勝利

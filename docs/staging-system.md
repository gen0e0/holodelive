# 演出キューシステム (StagingDirector)

## なぜキューが必要か

CPU プレイヤーのターンは `GameController` が同期再帰で処理するため、1 フレーム内に複数の `state_updated` シグナルが発火する。キューなしでは全アニメーションが同時に開始され、カードが重なって飛ぶ等の視覚的な問題が生じる。

StagingDirector はシグナルをキューに積み、`await` ベースの直列処理で演出を順序制御する。

## アーキテクチャ

```
GameSession
  ├── state_updated  ──→ GameScreen._on_state_updated()
  │                          └── director.enqueue_state_update(cs, events)
  └── actions_received ──→ GameScreen._on_actions_received()
                               └── director.enqueue_actions(actions)

StagingDirector
  _queue: [{type: STATE_UPDATE, cs, events}, {type: ACTIONS, actions}, ...]
           ↓
  _process_queue() ── while loop + await
    ├── STATE_UPDATE → _process_state_cue()
    │     ├── _capture_positions(_prev_cs)   ← 現在の視覚状態をスナップショット
    │     ├── refresh_fn.call(cs)            ← UI を新状態に即更新
    │     └── _stage_events(events, ...)     ← イベント列を順次アニメーション
    └── ACTIONS → _process_actions_cue()
          └── on_actions_ready.call(actions)  ← GameScreen に通知
```

### 位置キャプチャのタイミング

キーポイント: 位置キャプチャはエンキュー時ではなく**処理時**に行う。これにより、前のキューエントリの `refresh` で更新された UI 状態がキャプチャに反映される。

```
キュー: [state_update_A, state_update_B]

state_update_A の処理:
  1. capture_positions(prev_cs)  ← 初期状態の位置をキャプチャ
  2. refresh(cs_A)               ← UI を A の状態に更新
  3. stage_events(events_A)      ← A のアニメーション再生

state_update_B の処理:
  1. capture_positions(cs_A)     ← A の refresh 後の位置をキャプチャ ✓
  2. refresh(cs_B)               ← UI を B の状態に更新
  3. stage_events(events_B)      ← B のアニメーション再生
```

## 演出プリミティブ

### `_fly_card(card_data, face_up, from_xform, to_xform, duration)`

カード飛行の基本演出。AnimationLayer 上に一時的な CardView を生成し、Tween で移動させる。

1. CardView をインスタンス化し、`from_xform` の位置に配置
2. 並列 Tween で `position`, `scale`, `rotation` をアニメーション
3. `await tween.finished` で完了を待機
4. CardView を `queue_free()` で破棄

### `_delay(seconds)`

非アニメーションイベント (TURN_START, PASS 等) に小ウェイトを挟み、視覚的な区切りを作る。

## イベント演出一覧

| イベント | 演出メソッド | 内容 |
|---------|-------------|------|
| `DRAW` | `_cue_draw()` | デッキ → 手札/相手手札へカード飛行 |
| `PLAY_CARD` | `_cue_play_card()` | 手札/相手手札 → ステージ/楽屋へカード飛行 |
| その他 | (なし) | `EVENT_DELAY` 分の小ウェイト |

### hide → fly → show パターン

飛行アニメーション中は実カードと一時カードの重複表示を防ぐため:

1. **hide**: 移動先の実カードを非表示にする
2. **fly**: AnimationLayer 上の一時カードを飛行させる
3. **show**: 飛行完了後、実カードを再表示する

`await` により自然にこの順序が保証される。

## 新しいイベント演出の追加方法

1. `_execute_event()` の `match` に新しいイベントタイプを追加
2. 対応する `_cue_xxx()` メソッドを実装
3. メソッド内で `_fly_card()` や `_delay()` 等のプリミティブを `await` で使用

```gdscript
# 例: RETURN_HOME イベントの追加
func _cue_return_home(event: Dictionary, is_me: bool,
        old_positions: Dictionary) -> bool:
    var card_data: Dictionary = event.get("card", {})
    var iid: int = card_data.get("instance_id", -1)
    var from_xform: Dictionary = old_positions.get(iid, {})
    var to_xform: Dictionary = home_view.get_card_content_transform()
    if from_xform.is_empty() or to_xform.is_empty():
        return false
    await _fly_card(card_data, true, from_xform, to_xform, FLY_DURATION)
    return true
```

## キャンセル

`cancel_all()` は:
- `_cancelled = true` でキュー処理ループを中断
- `_queue.clear()` で未処理エントリを破棄
- AnimationLayer の子ノードを全削除

セッション切断時に `GameScreen.disconnect_session()` から呼ばれる。

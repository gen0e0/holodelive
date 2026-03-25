extends Node

## ゲーム全体の設定を管理するグローバルシングルトン。
## オートロードとして登録し、どこからでも GameConfig.xxx でアクセスする。

## アニメーション速度倍率。1.0=通常、2.0=2倍速、50.0=統合テスト用高速。
## StagingDirector やバナー演出など、時間に関わる全コンポーネントがこの値を参照する。
var animation_speed: float = 1.0

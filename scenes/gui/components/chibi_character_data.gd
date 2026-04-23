class_name ChibiCharacterData extends RefCounted

## Aseprite 書き出しデータをパースした結果を保持する。
## ChibiCharacterLoader が生成し、ChibiCharacter が参照する。

## スプライトシート PNG
var texture: Texture2D
## 1フレームのサイズ（px）
var frame_size: Vector2i

## 部位名 → スプライトシート上の矩形領域
## 例: "upper_arm_r" -> Rect2i(0, 1680, 240, 240)
var parts: Dictionary = {}

## 部位名 → 親グループ識別子（ない場合は空文字）
## 例: "upper_arm_r" -> "arm_r",  "torso" -> ""
var part_groups: Dictionary = {}

## 関節名（日本語） → キャンバス座標
## 例: "右足首" -> Vector2i(116, 192)
var pivots: Dictionary = {}

## 表情グループ名 → {部位名: Rect2i}
## 例: "normal" -> {"eyes_opened": Rect2i(...), "mouth_closed": Rect2i(...)}
var expressions: Dictionary = {}

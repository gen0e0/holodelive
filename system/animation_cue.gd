class_name AnimationCue
extends RefCounted

## ビルダーパターンによるアニメーションキュー。
## スキルスクリプトが emit_cue() で発行し、StagingDirector が実行する。

enum Style { DEFAULT, SPIN_OUT, TELEPORT, FADE, BOUNCE }

# --- 内部データ ---
var source: String = "find"        # "find" | "make"
var instance_id: int = -1
var action: String = ""            # "move" | "flip"
var style: Style = Style.DEFAULT

var from_zone: String = "auto"     # "auto", "my_hand", "op_hand", "deck", "home", "my_stage", "op_stage", "my_backstage", "op_backstage"
var to_zone: String = ""

var face_up_override: Variant = null  # null=自動, true/false=明示
var delay: float = 0.0
var anim_duration: float = -1.0       # -1=デフォルト

# flip 用
var to_face_down: bool = false


# =========================================================================
# ファクトリ
# =========================================================================

## 盤面上のカードを操作。from 未指定時は old_positions から自動解決。
static func find_card(iid: int) -> AnimationCue:
	var c := AnimationCue.new()
	c.source = "find"
	c.instance_id = iid
	c.from_zone = "auto"
	return c


## CardView を新規生成。from 指定必須。
static func make_card(iid: int) -> AnimationCue:
	var c := AnimationCue.new()
	c.source = "make"
	c.instance_id = iid
	c.from_zone = ""
	return c


# =========================================================================
# アクション（1つ必須）
# =========================================================================

func move(p_style: Style = Style.DEFAULT) -> AnimationCue:
	action = "move"
	style = p_style
	return self


func flip(p_to_face_down: bool) -> AnimationCue:
	action = "flip"
	to_face_down = p_to_face_down
	return self


# =========================================================================
# from ゾーン指定
# =========================================================================

func from_my_hand() -> AnimationCue:
	from_zone = "my_hand"
	return self

func from_op_hand() -> AnimationCue:
	from_zone = "op_hand"
	return self

func from_deck() -> AnimationCue:
	from_zone = "deck"
	return self

func from_home() -> AnimationCue:
	from_zone = "home"
	return self

func from_my_stage() -> AnimationCue:
	from_zone = "my_stage"
	return self

func from_op_stage() -> AnimationCue:
	from_zone = "op_stage"
	return self

func from_my_backstage() -> AnimationCue:
	from_zone = "my_backstage"
	return self

func from_op_backstage() -> AnimationCue:
	from_zone = "op_backstage"
	return self


# =========================================================================
# to ゾーン指定
# =========================================================================

func to_my_hand() -> AnimationCue:
	to_zone = "my_hand"
	return self

func to_op_hand() -> AnimationCue:
	to_zone = "op_hand"
	return self

func to_deck() -> AnimationCue:
	to_zone = "deck"
	return self

func to_home() -> AnimationCue:
	to_zone = "home"
	return self

func to_my_stage() -> AnimationCue:
	to_zone = "my_stage"
	return self

func to_op_stage() -> AnimationCue:
	to_zone = "op_stage"
	return self

func to_my_backstage() -> AnimationCue:
	to_zone = "my_backstage"
	return self

func to_op_backstage() -> AnimationCue:
	to_zone = "op_backstage"
	return self


# =========================================================================
# オプション
# =========================================================================

func face_up(val: bool) -> AnimationCue:
	face_up_override = val
	return self


func with_delay(d: float) -> AnimationCue:
	delay = d
	return self


func duration(d: float) -> AnimationCue:
	anim_duration = d
	return self

class_name AnimationCue
extends RefCounted

enum CueType { MOVE, FLIP, DESTROY, CREATE }
enum Style { DEFAULT, SPIN_OUT, TELEPORT, FADE, BOUNCE }

var cue_type: CueType
var style: Style = Style.DEFAULT
var instance_id: int = -1
var params: Dictionary = {}
var delay: float = 0.0


## delay を設定して自身を返すビルダーメソッド。
func with_delay(d: float) -> AnimationCue:
	delay = d
	return self


static func move(iid: int, p_style: Style = Style.DEFAULT) -> AnimationCue:
	var c := AnimationCue.new()
	c.cue_type = CueType.MOVE
	c.instance_id = iid
	c.style = p_style
	return c


static func flip(iid: int, to_face_down: bool,
		p_style: Style = Style.DEFAULT) -> AnimationCue:
	var c := AnimationCue.new()
	c.cue_type = CueType.FLIP
	c.instance_id = iid
	c.style = p_style
	c.params = {"to_face_down": to_face_down}
	return c

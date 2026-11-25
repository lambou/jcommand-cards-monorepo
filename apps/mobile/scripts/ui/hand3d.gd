extends SubViewportContainer
## A stylised 3D hand (white glove + sleeve), built from primitives, drawn over the table.
## It reaches in from the bottom of the screen, grips a card by its lower edge, carries it while the
## card flies, then lets go and slides away. Screen pixels map 1:1 to world units on the z = 0 plane.

const GLOVE := Color(0.97, 0.96, 0.92)
const SLEEVE := Color(0.13, 0.24, 0.42)
const CUFF := Color(0.93, 0.76, 0.28)
const CAM_DIST := 2000.0
const Settings := preload("res://scripts/game/settings.gd")

## Selectable looks: [name, glove/skin colour, sleeve colour].
const STYLES := [
	["Classic", Color(0.97, 0.96, 0.92), Color(0.13, 0.24, 0.42)],
	["Peach", Color(0.96, 0.80, 0.68), Color(0.55, 0.15, 0.22)],
	["Tan", Color(0.85, 0.65, 0.48), Color(0.15, 0.40, 0.30)],
	["Brown", Color(0.60, 0.40, 0.28), Color(0.85, 0.55, 0.15)],
	["Deep", Color(0.36, 0.23, 0.17), Color(0.40, 0.25, 0.60)],
	["Red", Color(0.85, 0.15, 0.15), Color(0.12, 0.12, 0.15)],
	["Shadow", Color(0.12, 0.12, 0.14), Color(0.70, 0.12, 0.18)],
]
const HAND_SCALE := 0.95
## The dealer's throw pose (see _throw): extend, stay out, relax, in seconds.
const THROW_EXTEND := 0.12
const THROW_HOLD := 0.10
const THROW_RELAX := 0.20
## While a card is being flipped (card_flip.gd sets "flip_angle" on it) the hand twists with it this much (1 = the whole turn,
## and it keeps that pose as it lets go and withdraws, like a hand that has just turned a card over).
const ROLL_FOLLOW := 1.0
## Where on the card the fingertips hold it, as a fraction of the card height below its centre.
const GRIP_Y := 0.2

## The thumb: where it joins the palm, its two segments and radius, and how it moves into the pinch (grip = 1).
## These angles were solved so that the thumb tip touches the index and the middle fingertip
## (tests/hand_pinch.gd checks it), with the contact point on the card's plane at its lower edge.
const THUMB_BASE := Vector3(-58.0, -78.0, 6.0)
const THUMB_LEN := [42.0, 34.0]
const THUMB_R := 15.5
const THUMB_PINCH := {"z": 20.1, "x": 1.5, "yaw": -34.1, "j0": -47.2, "j1": -0.1, "shift": Vector3(18.0, 14.0, -10.0)}

# x: position across the palm. len: segment lengths. open/closed: curl per joint (degrees).
# The grip is a pinch: the thumb and the two fingers next to it (index, middle) hold the card, while the two
# farthest fingers (ring, little) are curled tightly into the palm, out of the way.
const FINGERS := [
	{"x": -42.0, "len": [56.0, 38.0, 28.0], "r": 16.0, "spread": 7.0, "open": [-4.0, -8.0, -6.0], "closed": [-33.0, -90.0, -44.0]},
	{"x": -14.0, "len": [64.0, 42.0, 30.0], "r": 16.5, "spread": 2.5, "open": [-4.0, -8.0, -6.0], "closed": [-33.0, -90.0, -44.0]},
	{"x": 14.0, "len": [58.0, 40.0, 29.0], "r": 16.0, "spread": -2.5, "open": [-4.0, -8.0, -6.0], "closed": [-78.0, -105.0, -78.0]},
	{"x": 42.0, "len": [46.0, 32.0, 25.0], "r": 14.0, "spread": -8.0, "open": [-4.0, -8.0, -6.0], "closed": [-80.0, -108.0, -80.0]},
]

var pos := Vector2.ZERO # screen position of the grip point
var grip := 0.0 # 0 = open hand, 1 = gripping
var flick := 0.0 # 0..1: the throw. The index and middle fingers straighten and splay as a card leaves the hand

var _vp: SubViewport
var _cam: Camera3D
var _root: Node3D
var _palm: Node3D
var _fingers: Array = [] # {"base": Node3D, "joints": Array[Node3D], "def": Dictionary}
var _thumb_base: Node3D
var _thumb_joints: Array = []
var _follow: Control
var _skin_mat: StandardMaterial3D
var _sleeve_mat: StandardMaterial3D
var _dir := 1.0 # 1 = reaches up from the bottom (you), -1 = reaches down from the top (opponents)
var _scale := 1.0 # hand size follows the card it holds (opponents' cards start small)
var _tw: Tween
var _on_throw := Callable() # the dealer's card is sent by the throw itself (see deal_step), never by a separate timer
var _tf: Tween # the throw pose (flick / aim): its own timeline, so the next card's grab never cuts it short
var _tw2: Tween # grip pulses while a batch of cards is dealt
var _tilt := 0.0
var _aim := 0.0 # lean toward the player a card is thrown to (same sign convention as _tilt)
# The dealer's hand moves on a critically damped spring (deal_step) instead of eased tweens, so it keeps its
# speed when it lets a card go and glides back for the next one: no stop-and-restart between cards.
var _sp_on := false
var _sp_from := Vector2.ZERO
var _sp_v0 := Vector2.ZERO
var _sp_goal := Vector2.ZERO
var _sp_w := 1.0
var _sp_t := 0.0
var _vel := Vector2.ZERO
var _roll := 0.0 # twist of the wrist about the vertical axis, following a card that is being turned over
var _last_pos := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	_build_world()
	resized.connect(_fit)
	_fit()
	_activate(false)


func _build_world() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 0.9
	_vp.add_child(sun)

	_cam = Camera3D.new()
	_cam.current = true
	_vp.add_child(_cam)

	_root = Node3D.new()
	_root.scale = Vector3.ONE * HAND_SCALE
	_vp.add_child(_root)
	_build_hand()


func _fit() -> void:
	var h := maxf(size.y, 1.0)
	_cam.fov = rad_to_deg(2.0 * atan(h * 0.5 / CAM_DIST))
	_cam.far = CAM_DIST * 3.0
	_cam.position = Vector3(size.x * 0.5, -h * 0.5, CAM_DIST)


# ---------------------------------------------------------------- model

func _mat(c: Color, rough: float = 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _capsule(parent: Node3D, r: float, length: float, mat: Material) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = length + 2.0 * r
	cm.radial_segments = 20
	cm.rings = 6
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(0, length / 2.0, 0)
	parent.add_child(mi)


## A chain of capsules; returns the joint nodes (rotate each around X to curl).
func _chain(parent: Node3D, lens: Array, r: float, mat: Material) -> Array:
	var joints: Array = []
	var at: Node3D = parent
	var prev_len := 0.0
	for i in lens.size():
		var j := Node3D.new()
		j.position = Vector3(0, prev_len, 0)
		at.add_child(j)
		_capsule(j, r * (1.0 - 0.07 * float(i)), float(lens[i]), mat)
		joints.append(j)
		at = j
		prev_len = float(lens[i])
	return joints


func _build_hand() -> void:
	var skin := _mat(GLOVE)
	var sleeve := _mat(SLEEVE, 0.8)
	_skin_mat = skin
	_sleeve_mat = sleeve
	var cuff := _mat(CUFF, 0.4)

	# Local origin = grip point. The palm sits below and above the card plane so the fingers curl onto it.
	_palm = Node3D.new()
	_palm.position = Vector3(0, -112.0, 70.0)
	_root.add_child(_palm)

	var palm_mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	sm.material = skin
	palm_mesh.mesh = sm
	palm_mesh.position = Vector3(0, -62.0, 0)
	palm_mesh.scale = Vector3(66.0, 78.0, 34.0)
	_palm.add_child(palm_mesh)

	for def in FINGERS:
		var base := Node3D.new()
		base.position = Vector3(float(def["x"]), 0, 0)
		_palm.add_child(base)
		var joints := _chain(base, def["len"], float(def["r"]), skin)
		_fingers.append({"base": base, "joints": joints, "def": def})

	_thumb_base = Node3D.new()
	_thumb_base.position = THUMB_BASE
	_palm.add_child(_thumb_base)
	_thumb_joints = _chain(_thumb_base, THUMB_LEN, THUMB_R, skin)

	# Wrist cuff and a long sleeve that runs off the bottom of the screen.
	var cuff_mesh := CylinderMesh.new()
	cuff_mesh.top_radius = 54.0
	cuff_mesh.bottom_radius = 54.0
	cuff_mesh.height = 34.0
	cuff_mesh.material = cuff
	var cm := MeshInstance3D.new()
	cm.mesh = cuff_mesh
	cm.position = Vector3(0, -150.0, 0)
	_palm.add_child(cm)

	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 50.0
	arm_mesh.bottom_radius = 66.0
	arm_mesh.height = 1500.0
	arm_mesh.material = sleeve
	var am := MeshInstance3D.new()
	am.mesh = arm_mesh
	am.position = Vector3(0, -150.0 - 17.0 - 750.0, -4.0)
	_palm.add_child(am)


func _apply_pose() -> void:
	var g := smoothstep(0.0, 1.0, grip)
	var sway := sin(_time * 5.0) * 0.025 * (1.0 - g)
	var fl := smoothstep(0.0, 1.0, flick)
	for i in _fingers.size():
		var f: Dictionary = _fingers[i]
		var d: Dictionary = f["def"]
		var gf := g
		var splay := 0.0
		if i < 2: # index and middle: straighten and fan out as the card is thrown
			gf = g * (1.0 - fl)
			splay = fl * (9.0 if i == 0 else -6.0)
		(f["base"] as Node3D).rotation.z = deg_to_rad(lerpf(float(d["spread"]) * 1.7, float(d["spread"]) * 0.3, gf) + splay) + sway
		for j in 3:
			(f["joints"][j] as Node3D).rotation.x = deg_to_rad(lerpf(float(d["open"][j]), float(d["closed"][j]), gf))
	# The thumb comes across and presses its tip against the index and middle fingertips.
	var tp := THUMB_PINCH
	g = g * (1.0 - fl * 0.7) # the thumb lets go as the card is thrown
	_thumb_base.position = THUMB_BASE + (tp["shift"] as Vector3) * g
	_thumb_base.rotation.z = deg_to_rad(lerpf(64.0, float(tp["z"]), g))
	_thumb_base.rotation.x = deg_to_rad(lerpf(0.0, float(tp["x"]), g))
	_thumb_base.rotation.y = deg_to_rad(float(tp["yaw"])) * g
	(_thumb_joints[0] as Node3D).rotation.x = deg_to_rad(lerpf(-8.0, float(tp["j0"]), g))
	(_thumb_joints[1] as Node3D).rotation.x = deg_to_rad(lerpf(-6.0, float(tp["j1"]), g))
	_palm.rotation.x = lerpf(0.0, -0.14, g)


# ---------------------------------------------------------------- motion

func _activate(on: bool) -> void:
	_flush_throw()
	_sp_on = false
	if _tf != null:
		_tf.kill()
	visible = on
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)


## Reach in from below, grip `node` (a flying/resting card) and carry it for `carry_t` seconds, then leave.
## The card should start moving after `reach` seconds.
## `style` picks a STYLES entry (-1 = the player's own choice from settings).
## With `slide_to` (a grip point) the hand does not let go where the card lands: it keeps its hold and slides on
## to that point over `slide_t` seconds first (dealing a whole row of cards), then lets go.
func carry(node: Control, reach: float, carry_t: float, from_top: bool = false, style: int = -1,
		slide_to: Vector2 = Vector2.INF, slide_t: float = 0.0) -> void:
	if _tw != null:
		_tw.kill()
	if _tw2 != null:
		_tw2.kill()
	_sp_on = false # a draw owns the hand's position; the dealer's spring (deal_step) is off
	flick = 0.0
	_aim = 0.0
	_follow = null
	_dir = -1.0 if from_top else 1.0
	_roll = 0.0
	set_style(style if style >= 0 else Settings.hand_color)
	_scale = _scale_for(node)
	var grab := _grip_point(node)
	pos = Vector2(grab.x, _away_y())
	_last_pos = pos
	grip = 0.0
	_tilt = 0.0
	_activate(true)
	_tw = create_tween()
	_tw.tween_property(self, "pos", grab, reach).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(self, "grip", 1.0, reach * 0.45).set_delay(reach * 0.55)
	_tw.tween_callback(func(): _follow = node)
	_tw.tween_interval(carry_t)
	_tw.tween_callback(func(): _follow = null)
	if slide_to.is_finite() and slide_t > 0.0:
		_tw.tween_property(self, "pos", slide_to, slide_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(self, "grip", 0.0, 0.1)
	_tw.tween_property(self, "pos:y", _away_y(), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_callback(_activate.bind(false))


## Dealing a whole table: unlike carry(), the hand stays on screen between cards. It belongs to the dealer, so it
## reaches in from the dealer's own side: from the bottom for you (`from_top` false), from the top for a bot,
## coming in over `origin_x` (the dealer's seat; INF = straight above the card). It glides to `node` (taking
## `reach` s; the first call also brings it in from off-screen) and pinches it. The caller sends the card on its
## way the moment the hand arrives: it shoots out of the fingers as the index and middle fingers straighten and
## splay and the hand leans and pushes toward `aim_x` (-1..1: the side of the player the card goes to), over
## `flick_t` s, and `on_throw` (if given) is called at that very moment: that is where the caller launches the card.
## The hand does not ride the card (that would make it jump to the card's launch speed); it waits
## where it is for the next call. Call deal_end() when the last card is out.
func deal_step(node: Control, reach: float, flick_t: float, from_top: bool, style: int = -1,
		origin_x: float = INF, aim_x: float = 0.0, on_throw: Callable = Callable()) -> void:
	_flush_throw() # a throw cut short by this call still sends its card
	if _tw != null:
		_tw.kill()
	_follow = null
	if not visible:
		_dir = -1.0 if from_top else 1.0
		_roll = 0.0
		set_style(style if style >= 0 else Settings.hand_color)
		_scale = _scale_for(node)
		pos = Vector2(origin_x if is_finite(origin_x) else _grip_point(node).x, _away_y())
		_last_pos = pos
		_vel = Vector2.ZERO
		grip = 0.0
		flick = 0.0
		_aim = 0.0
		_tilt = 0.0
		_activate(true)
	_on_throw = on_throw # after _activate(), which flushes whatever was pending
	_spring_to(_grip_point(node), reach)
	_tw = create_tween()
	_tw.tween_property(self, "grip", 1.0, reach * 0.8)
	_tw.parallel().tween_property(self, "_scale", _scale_for(node), reach)
	# The throw: a short push toward the table and the player while the fingers straighten and fan out.
	_tw.tween_callback(func():
		_spring_to(pos + Vector2(aim_x * 40.0, -_dir * 25.0), flick_t)
		_throw(aim_x, maxf(flick_t * 0.6, THROW_EXTEND))
		_flush_throw()) # the card leaves the hand now, in the same frame the fingers start to extend
	_tw.tween_interval(maxf(flick_t * 0.6, THROW_EXTEND))
	_tw.tween_property(self, "grip", 0.2, 0.06)


## Calls (once) the `on_throw` the current deal_step was given: the dealer's card is launched by the hand's own
## throw, so the card and the fingers can never drift apart (a separate timer would, e.g. over a loading hitch).
func _flush_throw() -> void:
	if _on_throw.is_valid():
		var cb := _on_throw
		_on_throw = Callable()
		cb.call()


## The throw pose on its own timeline: index and middle fingers extend over `extend` s, stay out for THROW_HOLD,
## then relax. The times are absolute (not scaled to the deal's pace), so the pose is long enough to be seen on a
## slow frame rate, and the next card's grab cannot cut it short.
func _throw(aim_x: float, extend: float) -> void:
	if _tf != null:
		_tf.kill()
	_tf = create_tween()
	_tf.tween_property(self, "flick", 1.0, extend)
	_tf.parallel().tween_property(self, "_aim", -aim_x * 0.45, extend)
	_tf.tween_interval(THROW_HOLD)
	_tf.tween_property(self, "flick", 0.0, THROW_RELAX)
	_tf.parallel().tween_property(self, "_aim", 0.0, THROW_RELAX)


## The dealer's hand leaves the way it came, gliding back out of the screen.
func deal_end() -> void:
	_flush_throw()
	if _tw != null:
		_tw.kill()
	_follow = null
	if _tf != null:
		_tf.kill()
	_spring_to(Vector2(pos.x, _away_y()), 0.85)
	_tw = create_tween()
	_tw.tween_property(self, "grip", 0.0, 0.1)
	_tw.parallel().tween_property(self, "flick", 0.0, 0.2)
	_tw.parallel().tween_property(self, "_aim", 0.0, 0.2)
	_tw.tween_interval(0.5)
	_tw.tween_callback(_activate.bind(false))


## Glides the hand to `goal`, arriving in about `reach` s, carrying on at the speed it already has.
func _spring_to(goal: Vector2, reach: float) -> void:
	_sp_from = pos
	_sp_v0 = _vel
	_sp_goal = goal
	_sp_w = 7.5 / maxf(reach, 0.05) # critically damped: within half a percent of the goal after `reach`
	_sp_t = 0.0
	_sp_on = true


## Switch to another card mid-carry: the grip relaxes to a flat pushing hand, follows `node` for `hold`
## seconds (a 2 sliding under the pile), then lets go and leaves.
func hand_over(node: Control, hold: float) -> void:
	if _tw != null:
		_tw.kill()
	_follow = node
	_tw = create_tween()
	_tw.tween_property(self, "grip", 0.35, 0.12)
	_tw.tween_interval(maxf(hold - 0.12, 0.0))
	_tw.tween_callback(func(): _follow = null)
	_tw.tween_property(self, "grip", 0.0, 0.1)
	_tw.tween_property(self, "pos:y", _away_y(), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_callback(_activate.bind(false))


## Style index for the player (bot_index 0) or bot n: the player's choice, then the next ones along,
## so everyone at the table differs (up to STYLES.size() players).
static func style_for(bot_index: int, base: int) -> int:
	return posmod(base + bot_index, STYLES.size())


## While the hand holds still at the destination, squeeze `count` times (one per card released).
func pulse(count: int, step: float, delay: float) -> void:
	if _tw2 != null:
		_tw2.kill()
	_tw2 = create_tween()
	_tw2.tween_interval(delay)
	for i in count:
		_tw2.tween_property(self, "grip", 0.25, step * 0.4)
		_tw2.tween_property(self, "grip", 1.0, step * 0.6)


func set_style(i: int) -> void:
	var st: Array = STYLES[posmod(i, STYLES.size())]
	_skin_mat.albedo_color = st[1]
	_sleeve_mat.albedo_color = st[2]


func _grip_point(node: Control) -> Vector2:
	var dx := float(node.get_meta("grip_dx", 0.0)) # a card being flipped is held by its hinge edge
	return node.position + node.size / 2.0 + Vector2(dx, node.size.y * node.scale.y * GRIP_Y * _dir)


## Off-screen resting spot: below the screen for your hand, above it for the opponents'.
func _away_y() -> float:
	return size.y + 430.0 if _dir > 0.0 else -430.0


## Small cards (a bot's, at its seat) get a smaller hand; it grows as the card does.
func _scale_for(node: Control) -> float:
	return clampf(node.size.x * node.scale.x / 180.0, 0.6, 1.0)


func _process(delta: float) -> void:
	_time += delta
	if _follow != null and is_instance_valid(_follow):
		pos = _grip_point(_follow)
	elif _sp_on:
		_sp_t += delta
		var d0 := _sp_from - _sp_goal
		pos = _sp_goal + (d0 + (_sp_v0 + d0 * _sp_w) * _sp_t) * exp(-_sp_w * _sp_t)
	var vel := (pos - _last_pos) / maxf(delta, 0.001)
	_vel = vel
	_last_pos = pos
	# Lean into the direction of travel.
	_tilt = lerpf(_tilt, clampf(-vel.x * 0.0004, -0.4, 0.4), minf(delta * 8.0, 1.0))
	_root.position = Vector3(pos.x, -pos.y, 0.0)
	if _follow != null and is_instance_valid(_follow):
		_scale = lerpf(_scale, _scale_for(_follow), minf(delta * 10.0, 1.0))
	_root.scale = Vector3.ONE * HAND_SCALE * _scale
	var want_roll := _roll # holds its twist after letting go; carry() resets it for the next reach
	if _follow != null and is_instance_valid(_follow):
		want_roll = float(_follow.get_meta("flip_angle", 0.0)) * ROLL_FOLLOW
	_roll = lerpf(_roll, want_roll, minf(delta * 14.0, 1.0))
	_root.rotation.y = _roll
	_root.rotation.z = (PI if _dir < 0.0 else 0.0) + (_tilt + _aim) * _dir
	_apply_pose()

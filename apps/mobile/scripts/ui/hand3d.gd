extends SubViewportContainer
## A stylised 3D hand (white glove + sleeve), built from primitives, drawn over the table.
## It reaches in from the bottom of the screen, grips a card by its lower edge, carries it while the
## card flies, then lets go and slides away. Screen pixels map 1:1 to world units on the z = 0 plane.

const GLOVE := Color(0.97, 0.96, 0.92)
const SLEEVE := Color(0.13, 0.24, 0.42)
const CUFF := Color(0.93, 0.76, 0.28)
const CAM_DIST := 2000.0
const HAND_SCALE := 0.95
## Where on the card the fingertips hold it, as a fraction of the card height below its centre.
const GRIP_Y := 0.2

# x: position across the palm. len: segment lengths. open/closed: curl per joint (degrees).
const FINGERS := [
	{"x": -42.0, "len": [56.0, 38.0, 28.0], "r": 16.0, "spread": 7.0, "open": [-4.0, -8.0, -6.0], "closed": [-30.0, -52.0, -40.0]},
	{"x": -14.0, "len": [64.0, 42.0, 30.0], "r": 16.5, "spread": 2.5, "open": [-4.0, -8.0, -6.0], "closed": [-30.0, -52.0, -40.0]},
	{"x": 14.0, "len": [58.0, 40.0, 29.0], "r": 16.0, "spread": -2.5, "open": [-4.0, -8.0, -6.0], "closed": [-30.0, -52.0, -40.0]},
	{"x": 42.0, "len": [46.0, 32.0, 25.0], "r": 14.0, "spread": -8.0, "open": [-4.0, -8.0, -6.0], "closed": [-30.0, -52.0, -40.0]},
]

var pos := Vector2.ZERO # screen position of the grip point
var grip := 0.0 # 0 = open hand, 1 = gripping

var _vp: SubViewport
var _cam: Camera3D
var _root: Node3D
var _palm: Node3D
var _fingers: Array = [] # {"base": Node3D, "joints": Array[Node3D], "def": Dictionary}
var _thumb_base: Node3D
var _thumb_joints: Array = []
var _follow: Control
var _tw: Tween
var _tilt := 0.0
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
	_thumb_base.position = Vector3(-58.0, -78.0, 6.0)
	_palm.add_child(_thumb_base)
	_thumb_joints = _chain(_thumb_base, [42.0, 34.0], 15.5, skin)

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
	for f in _fingers:
		var d: Dictionary = f["def"]
		(f["base"] as Node3D).rotation.z = deg_to_rad(lerpf(float(d["spread"]) * 1.7, float(d["spread"]) * 0.3, g)) + sway
		for j in 3:
			(f["joints"][j] as Node3D).rotation.x = deg_to_rad(lerpf(float(d["open"][j]), float(d["closed"][j]), g))
	_thumb_base.rotation.z = deg_to_rad(lerpf(64.0, 40.0, g))
	_thumb_base.rotation.x = deg_to_rad(lerpf(0.0, -16.0, g))
	(_thumb_joints[0] as Node3D).rotation.x = deg_to_rad(lerpf(-8.0, -26.0, g))
	(_thumb_joints[1] as Node3D).rotation.x = deg_to_rad(lerpf(-6.0, -34.0, g))
	_palm.rotation.x = lerpf(0.0, -0.14, g)


# ---------------------------------------------------------------- motion

func _activate(on: bool) -> void:
	visible = on
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)


## Reach in from below, grip `node` (a flying/resting card) and carry it for `carry_t` seconds, then leave.
## The card should start moving after `reach` seconds.
func carry(node: Control, reach: float, carry_t: float) -> void:
	if _tw != null:
		_tw.kill()
	_follow = null
	var grab := _grip_point(node)
	pos = Vector2(grab.x, size.y + 420.0)
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
	_tw.tween_property(self, "grip", 0.0, 0.1)
	_tw.tween_property(self, "pos:y", size.y + 450.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_callback(_activate.bind(false))


func _grip_point(node: Control) -> Vector2:
	return node.position + node.size / 2.0 + Vector2(0, node.size.y * node.scale.y * GRIP_Y)


func _process(delta: float) -> void:
	_time += delta
	if _follow != null and is_instance_valid(_follow):
		pos = _grip_point(_follow)
	var vel := (pos - _last_pos) / maxf(delta, 0.001)
	_last_pos = pos
	# Lean into the direction of travel.
	_tilt = lerpf(_tilt, clampf(-vel.x * 0.0004, -0.4, 0.4), minf(delta * 8.0, 1.0))
	_root.position = Vector3(pos.x, -pos.y, 0.0)
	_root.rotation.z = _tilt
	_apply_pose()

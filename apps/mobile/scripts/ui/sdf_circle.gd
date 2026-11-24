extends Control
## A crisp disc (optionally with a border ring) drawn by assets/shaders/sdf_circle.gdshader.
## Place it as a child; `center` is in the parent's local space.

const SHADER := preload("res://assets/shaders/sdf_circle.gdshader")
const PAD := 2.0   # transparent margin so the anti-aliased edge is never clipped

var radius := 30.0
var border := 0.0
var fill_color := Color.WHITE
var border_color := Color(0, 0, 0, 0)
var center := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER


func setup(c: Vector2, r: float, fill: Color, border_w: float = 0.0, border_col: Color = Color(0, 0, 0, 0)) -> void:
	center = c
	radius = r
	fill_color = fill
	border = border_w
	border_color = border_col
	var side := (r + PAD) * 2.0
	size = Vector2(side, side)
	position = c - size / 2.0
	var m := material as ShaderMaterial
	m.set_shader_parameter("fill_color", fill)
	m.set_shader_parameter("border_color", border_col)
	m.set_shader_parameter("radius", r)
	m.set_shader_parameter("border", border_w)
	m.set_shader_parameter("node_size", size)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

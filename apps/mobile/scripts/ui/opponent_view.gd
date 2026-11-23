extends Control
## An opponent's seat: name, card count, fanned card backs, status, and a preview of the
## last card they played (gold border + "ON TOP" while it is the card on top of the stack).

const TextFx := preload("res://scripts/ui/text_fx.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")
const CardView := preload("res://scripts/ui/card_view.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")
const Settings := preload("res://scripts/game/settings.gd")

var player_name := ""
var avatar_index := 0
var count := 0
var active := false
var status := ""
var has_last := false
var last_is_top := false
var check := false # exactly one card left

var mini: Control


func _ready() -> void:
	mini = CardView.new()
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.visible = false
	add_child(mini)
	_layout_mini()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_mini()
		queue_redraw()


## The last-played preview is deliberately small: a chip, not a second pile.
func mini_size() -> Vector2:
	var mh := clampf(size.y * 0.62, 70.0, 150.0)
	return Vector2(mh * CardView.BASE.x / CardView.BASE.y, mh)


func mini_rect() -> Rect2:
	var ms := mini_size()
	return Rect2(Vector2(size.x - ms.x - 14.0, size.y - ms.y - 40.0), ms)


func _layout_mini() -> void:
	if mini == null:
		return
	var r := mini_rect()
	mini.size = r.size
	mini.position = r.position


func update_info(p_name: String, p_count: int, p_active: bool, p_status: String, last_card: Dictionary, p_last_top: bool, p_check: bool = false) -> void:
	check = p_check
	set_process(check)
	player_name = p_name
	count = p_count
	active = p_active
	status = p_status
	has_last = not last_card.is_empty()
	last_is_top = p_last_top and has_last
	if has_last:
		mini.set_card(last_card, true)
		mini.set_flags(false, last_is_top)
	mini.visible = has_last
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw() # drives the CHECK pulse


func _draw() -> void:
	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var pulse := 0.5 if Settings.reduce() else 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 0.5)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(22)
	box.bg_color = Color(0.05, 0.22, 0.14, 0.85)
	box.set_border_width_all(6 if active else 2)
	box.border_color = Color(1.0, 0.82, 0.2) if active else Color(1, 1, 1, 0.25)
	if check:
		box.bg_color = Color(0.27, 0.06, 0.07, 0.92)
		box.set_border_width_all(7)
		box.border_color = Color(1.0, 0.25, 0.2, 1.0)
		box.shadow_color = Color(1.0, 0.15, 0.1, 0.22 + 0.12 * pulse)
		box.shadow_size = int(8 + 6 * pulse)
	draw_style_box(box, Rect2(Vector2.ZERO, size))

	var ring := Color(1.0, 0.82, 0.2) if active else Color(1, 1, 1, 0.55)
	if check:
		ring = Color(1.0, 0.25, 0.2)
	Avatar.draw_avatar(self, avatar_index, Vector2(54, 44), 32.0, ring, 5.0 if (active or check) else 2.5)
	TextFx.draw(self, font, Vector2(100, 56), player_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 114.0, 42, Color.WHITE)

	var mr := mini_rect()
	var fan_w := mr.position.x - 28.0

	# Fan of card backs (at most 8 drawn), left of the last-played preview.
	var shown := mini(count, 8)
	var cw := minf(56.0, fan_w * 0.3)
	var chh := cw * 1.42
	var spread := minf(cw * 0.55, (fan_w - cw) / maxf(float(shown - 1), 1.0))
	var total_w := cw + spread * float(maxi(shown - 1, 0))
	var x0 := 14.0 + (fan_w - total_w) / 2.0
	var y0 := 64.0 + (maxf(size.y - 64.0 - 52.0, chh) - chh) / 2.0
	for i in shown:
		var r := Rect2(Vector2(x0 + spread * i, y0), Vector2(cw, chh))
		CardView.draw_back(self, r)

	var label := "%d card%s" % [count, "" if count == 1 else "s"]
	var gold := Color(1.0, 0.85, 0.3)
	if status != "":
		label = status
	TextFx.draw(self, font, Vector2(14, size.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, fan_w, 36,
		gold if status != "" else Color(1, 1, 1, 0.85))

	# Last-played slot.
	if not has_last:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0, 0, 0, 0.18)
		empty.set_corner_radius_all(12)
		empty.set_border_width_all(2)
		empty.border_color = Color(1, 1, 1, 0.3)
		draw_style_box(empty, mr)
	TextFx.draw(self, font, Vector2(mr.position.x - 20, size.y - 14), "ON TOP" if last_is_top else "last",
		HORIZONTAL_ALIGNMENT_CENTER, mr.size.x + 40, 28, gold if last_is_top else Color(1, 1, 1, 0.6))

	if check:
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color(0.9, 0.08, 0.1)
		badge.set_corner_radius_all(14)
		badge.set_border_width_all(3)
		badge.border_color = Color.WHITE
		var br := Rect2(size.x - 150.0, -16.0, 138.0, 40.0)
		draw_style_box(badge, br)
		TextFx.draw(self, font, Vector2(br.position.x, br.position.y + 30.0), "CHECK!", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 28, Color.WHITE)

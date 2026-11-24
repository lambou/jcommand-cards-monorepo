class_name CardFlip
extends RefCounted
## The "real card" flip: a face-down card is peeled off the bank, turned over in the air and lands face-up.
## A Control only has a 2D transform, so the 3D feel is faked from cues that move together:
##   - squash across the width (cos of the turn angle), with a cream paper edge instead of a hairline,
##   - the card swells and leans towards the viewer while it is lifted, and its shadow grows with the height,
##   - one side darkens as it turns, then a highlight sweeps across the face once it has turned,
##   - a short peel (lift + lean) before it travels, and a small squash-settle as it lands.
## Used by the playground (`--flipplay`); the table calls the same `run` when it is switched over.

const CardView := preload("res://scripts/ui/card_view.gd")

## Fractions of the flight. The caller starts moving the card at PEEL; the turn runs PEEL..TURN_END; the
## lift fades before LAND, where the card slaps down.
const PEEL := 0.2
const TURN_END := 0.80
const LAND := 0.88
const LIFT_SCALE := 0.20   # extra height at the top of the lift (card nearer the camera)
const TILT_DEG := 8.0      # how far the card leans over mid-turn
const EDGE := 0.085        # thinnest the card gets (the visible paper edge)
const PERSP := 0.30        # perspective: how much taller the nearer vertical edge gets mid-turn
const TURN_MIN := 0.30     # seconds: the turn never takes less than this, so it can be seen
## A right-handed flip: the right edge is the hinge, so the card turns over from left to right and ends up
## this far (in card widths) further right than it would after a flip about its centre; the path allows for it.
const FLIP_SHIFT := 0.9
## How far towards the hinge edge the glove holds the card (1 = right at the edge).
const GRIP_SIDE := 0.7
const DIM := 0.10          # how much darker it is edge-on


## Pose of a card `t` (0..1) through its flight. `from_scale` is the size it starts at relative to its
## final size; `tilt_dir` (+1/-1) picks the side it leans to.
static func pose(v: Control, card: Dictionary, t: float, from_scale: float, from_c: Vector2, to_c: Vector2,
		tilt_dir: float = 1.0) -> void:
	var f := clampf((t - PEEL) / (TURN_END - PEEL), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f) # smoothstep: the turn starts and ends gently
	var angle := f * PI
	var raw := absf(cos(angle))
	var turn := maxf(raw, EDGE) # never negative, so the face is not mirrored
	var peel := sin(clampf(t / PEEL, 0.0, 1.0) * PI * 0.5)
	var settle := 1.0 - smoothstep(0.78, LAND, t) # the lift is gone just before it lands
	var lift := maxf(peel * 0.45, sin(angle)) * settle
	var slap := sin(clampf((t - LAND) / (1.0 - LAND), 0.0, 1.0) * PI) # lands: squashes a little, then rests
	var base := lerpf(from_scale, 1.0, smoothstep(0.35, 1.0, t)) # shrinks to hand size late, after the turn
	# Position: the travel starts after the peel; the hinge makes the card sweep to the right as it turns,
	# so the path aims that far to the left of the target and the sweep brings it exactly onto it.
	var u := clampf((t - PEEL) / (1.0 - PEEL), 0.0, 1.0) # travel eases in (no jerk after the peel) and out
	var path := from_c.lerp(to_c - Vector2(FLIP_SHIFT * v.size.x * tilt_dir, 0.0), 1.0 - pow(1.0 - smoothstep(0.0, 1.0, u), 2.0))
	var sweep_x := FLIP_SHIFT * v.size.x * base * 0.5 * (1.0 - cos(angle)) * tilt_dir
	v.position = path + Vector2(sweep_x, 0.0) - v.size / 2.0
	# For the 3D glove (hand3d.gd): where the hinge is relative to the card's centre (it holds that edge, and
	# slides to it during the peel, lets go as the card lands) and how far the card has turned (the hand rolls along with it).
	v.set_meta("flip_angle", angle)
	v.set_meta("grip_dx", v.size.x * base * 0.5 * cos(angle) * GRIP_SIDE * smoothstep(0.0, PEEL, t) * (1.0 - smoothstep(0.8, 1.0, t)) * tilt_dir)
	v.scale = Vector2(base * turn * (1.0 + LIFT_SCALE * 0.5 * lift + 0.05 * slap),
		base * (1.0 + LIFT_SCALE * lift - 0.06 * slap))
	v.rotation = deg_to_rad(TILT_DEG) * tilt_dir * (sin(angle) + 0.35 * peel * (1.0 - f)) * settle
	# Darkest edge-on; once the face is showing the light comes back quickly (no grey face after the reveal).
	var lit := sin(angle) if angle < PI * 0.5 else pow(sin(angle), 2.0)
	var shade := 1.0 - DIM * lit
	v.modulate = Color(shade, shade, shade, 1.0)
	# The card is a touch shorter edge-on (it is turning away from us), on top of the perspective.
	v.scale.y *= 1.0 - 0.07 * (1.0 - smoothstep(EDGE, 0.30, raw))
	if v is CardView:
		var cv := v as CardView
		var up := angle >= PI * 0.5
		if cv.face_up != up:
			cv.set_card(card, up)
		var edge := 1.0 - smoothstep(EDGE, 0.30, raw)
		var sweep := clampf((t - 0.68) / 0.30, 0.0, 1.0)
		# The free (left) edge is the nearer one all through the turn, so it swaps sides on screen at 90 degrees.
		var persp := -PERSP * sin(angle) * clampf(cos(angle) / 0.2, -1.0, 1.0) * tilt_dir
		cv.set_fx(lift, edge, 0.30 * lit, sweep if up else 0.0, persp)


## Flies `v` (centre `from_c` to centre `to_c`) over `dur` seconds, turning it over like a right-handed flip.
## This drives position, scale, lean, shade, shadow, edge, highlight and the face. With reduce motion the card
## just moves, grows into place and changes face half way.
static func run(_host: Node, v: Control, card: Dictionary, dur: float, from_scale: float,
		from_c: Vector2, to_c: Vector2, reduce: bool = false, tilt_dir: float = 1.0) -> Tween:
	var tw := v.create_tween() # bound to the card: it stops if the caller frees the flyer on landing
	if reduce:
		tw.tween_property(v, "position", to_c - v.size / 2.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(v, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_callback(func(): (v as CardView).set_card(card, true)).set_delay(dur * 0.45)
		return tw
	tw.tween_method(func(t: float):
		if is_instance_valid(v):
			pose(v, card, t, from_scale, from_c, to_c, tilt_dir), 0.0, 1.0, dur)
	tw.tween_callback(func():
		if not is_instance_valid(v): # the caller frees the flyer when it lands
			return
		v.position = to_c - v.size / 2.0
		v.set_meta("flip_angle", 0.0)
		v.set_meta("grip_dx", 0.0)
		v.rotation = 0.0
		v.modulate = Color.WHITE
		v.scale = Vector2.ONE
		if v is CardView:
			(v as CardView).set_fx(0.0, 0.0, 0.0, 0.0, 0.0))
	return tw


## The shortest flight that still gives the turn TURN_MIN seconds (the turn is TURN_END - PEEL of the flight).
static func min_duration() -> float:
	return TURN_MIN / (TURN_END - PEEL)

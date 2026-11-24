extends Node
## Sound effects, synthesised in code (sine tones, filtered noise, sweeps) so the game needs no
## audio assets yet. Add one instance to the tree, then call `Sfx.play("name")` from anywhere.
##
## Names: combo_2..combo_5, jackpot, play, draw, deal, slide, thump, roar, penalty, stop, check, turn, nope, win, lose.

const Settings := preload("res://scripts/game/settings.gd")

const RATE := 22050
const VOICES := 10

static var instance: Node = null

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	instance = self
	_rng.seed = 12345
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Plays a named sound. `gain` (0..1) scales it relative to the user's volume setting.
static func play(sound: String, gain: float = 1.0) -> void:
	if instance != null and is_instance_valid(instance):
		instance._play(sound, gain)


func _play(sound: String, gain: float) -> void:
	Settings.load_settings()
	if not Settings.sound_enabled or Settings.volume <= 0.0 or not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(clampf(Settings.volume * gain, 0.0001, 1.0))
	p.play()


## Writes every sound as a .wav so they can be listened to outside the game.
func export_all(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for name in _streams:
		(_streams[name] as AudioStreamWAV).save_to_wav(dir.path_join("%s.wav" % name))
	print("exported %d sounds to %s" % [_streams.size(), dir])


# ---------------------------------------------------------------- the sound bank

func _build() -> void:
	# Card laid on the pile: a soft slap.
	var b := _buf(0.14)
	_noise(b, 0.0, 0.08, 0.55, 45.0, 0.25)
	_tone(b, 0.0, 180.0, 0.09, 0.4, 38.0)
	_streams["play"] = _stream(b)

	# Card drawn / dealt: a light tick.
	b = _buf(0.09)
	_noise(b, 0.0, 0.05, 0.4, 55.0, 0.5)
	_tone(b, 0.0, 620.0, 0.05, 0.16, 60.0)
	_streams["draw"] = _stream(b)
	_streams["deal"] = _streams["draw"]

	# A 2 sliding under the pile: a soft swish.
	b = _buf(0.4)
	_noise(b, 0.0, 0.36, 0.9, 6.0, 0.1)
	_streams["slide"] = _stream(b)

	# 7: a low thump.
	b = _buf(0.4)
	_tone(b, 0.0, 85.0, 0.34, 0.8, 11.0)
	_noise(b, 0.0, 0.1, 0.3, 30.0, 0.1)
	_streams["thump"] = _stream(b)

	# Lion: a falling growl.
	b = _buf(0.7)
	_sweep(b, 0.0, 250.0, 70.0, 0.6, 0.5, 3.5)
	_sweep(b, 0.0, 500.0, 140.0, 0.6, 0.22, 4.0)
	_noise(b, 0.0, 0.5, 0.14, 5.0, 0.08)
	_streams["roar"] = _stream(b)

	# Taking a penalty: two sinking notes.
	b = _buf(0.7)
	_tone(b, 0.0, 330.0, 0.3, 0.5, 7.0, [1.0, 0.25])
	_tone(b, 0.15, 247.0, 0.4, 0.5, 6.0, [1.0, 0.25])
	_streams["penalty"] = _stream(b)

	# Stop: two short beeps.
	b = _buf(0.4)
	_tone(b, 0.0, 440.0, 0.09, 0.45, 16.0, [1.0, 0.4])
	_tone(b, 0.14, 330.0, 0.14, 0.45, 12.0, [1.0, 0.4])
	_streams["stop"] = _stream(b)

	# Check: a soft two-note chime (a bell, not a buzzer).
	b = _buf(1.0)
	_tone(b, 0.0, 659.25, 0.6, 0.4, 5.0, [1.0, 0.3, 0.1])
	_tone(b, 0.17, 880.0, 0.75, 0.4, 4.5, [1.0, 0.3, 0.1])
	_streams["check"] = _stream(b)

	# Your turn: a tiny ping.
	b = _buf(0.25)
	_tone(b, 0.0, 880.0, 0.2, 0.32, 14.0, [1.0, 0.2])
	_streams["turn"] = _stream(b)

	# Illegal tap: a short downward blip.
	b = _buf(0.2)
	_sweep(b, 0.0, 320.0, 190.0, 0.14, 0.42, 14.0)
	_streams["nope"] = _stream(b)

	# Win: a rising arpeggio and a final chord.
	b = _buf(1.7)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_tone(b, 0.14 * float(i), notes[i], 0.5, 0.32, 4.5, [1.0, 0.35, 0.15])
	for f in [523.25, 659.25, 783.99, 1046.5]:
		_tone(b, 0.62, f, 1.0, 0.16, 2.5, [1.0, 0.3])
	_streams["win"] = _stream(b)

	# Lose: three falling notes, gentle.
	b = _buf(1.1)
	var down := [392.0, 329.63, 261.63]
	for i in down.size():
		_tone(b, 0.2 * float(i), down[i], 0.55, 0.32, 5.0, [1.0, 0.25])
	_streams["lose"] = _stream(b)

	_build_combos()
	_build_reactions()


## Combo chimes climb a major arpeggio (one more note each step); the jackpot is a long fanfare.
func _build_combos() -> void:
	var scale := [523.25, 659.25, 783.99, 1046.5, 1318.5]
	for n in range(2, 6):
		var b := _buf(0.5 + 0.1 * float(n))
		for i in n:
			_tone(b, 0.07 * float(i), scale[i], 0.4, 0.3, 7.0, [1.0, 0.35, 0.12])
		_tone(b, 0.07 * float(n - 1), scale[n - 1] * 2.0, 0.3, 0.1, 10.0)
		_streams["combo_%d" % n] = _stream(b)

	# Jackpot: rising run, big held chord, glittering sparkle on top.
	var j := _buf(2.6)
	var run := [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0]
	for i in run.size():
		_tone(j, 0.09 * float(i), run[i], 0.5, 0.28, 5.0, [1.0, 0.35, 0.15])
	for f in [523.25, 659.25, 783.99, 1046.5]:
		_tone(j, 0.6, f, 1.9, 0.17, 1.6, [1.0, 0.4, 0.15])
	_tone(j, 0.6, 130.8, 1.6, 0.3, 2.0, [1.0, 0.5])
	for i in 14:
		_tone(j, 0.7 + 0.08 * float(i), 1900.0 + 140.0 * float(i % 5), 0.12, 0.07, 22.0)
	_streams["jackpot"] = _stream(j)


## Short, friendly sounds for the emoji reactions (see reactions.gd).
func _build_reactions() -> void:
	# Generic pop (cool).
	var b := _buf(0.2)
	_sweep(b, 0.0, 380.0, 900.0, 0.1, 0.4, 14.0)
	_tone(b, 0.07, 1180.0, 0.1, 0.22, 20.0)
	_streams["react_pop"] = _stream(b)

	# Cheer (gg, clap): a bright two-note "ta-da" with a little sparkle.
	b = _buf(0.6)
	_tone(b, 0.0, 659.25, 0.16, 0.34, 9.0, [1.0, 0.3])
	_tone(b, 0.11, 987.77, 0.4, 0.34, 6.0, [1.0, 0.3, 0.1])
	_noise(b, 0.12, 0.2, 0.08, 14.0, 0.7)
	_streams["react_cheer"] = _stream(b)

	# Laugh: a bouncy "ha-ha-ha".
	b = _buf(0.7)
	for i in 4:
		var f := 540.0 - 40.0 * float(i)
		_sweep(b, 0.14 * float(i), f * 1.15, f * 0.9, 0.1, 0.34, 12.0)
		_noise(b, 0.14 * float(i), 0.05, 0.1, 30.0, 0.35)
	_streams["react_laugh"] = _stream(b)

	# Wow: a quick rising whistle.
	b = _buf(0.5)
	_sweep(b, 0.0, 420.0, 1250.0, 0.32, 0.36, 3.5)
	_tone(b, 0.3, 1250.0, 0.18, 0.2, 10.0, [1.0, 0.2])
	_streams["react_wow"] = _stream(b)

	# Hmm: two soft thinking blips.
	b = _buf(0.5)
	_tone(b, 0.0, 330.0, 0.14, 0.3, 14.0, [1.0, 0.25])
	_tone(b, 0.22, 392.0, 0.2, 0.3, 11.0, [1.0, 0.25])
	_streams["react_think"] = _stream(b)

	# Oops: a wobbly slide down and back up.
	b = _buf(0.55)
	_sweep(b, 0.0, 620.0, 300.0, 0.25, 0.36, 5.0)
	_sweep(b, 0.22, 300.0, 460.0, 0.22, 0.3, 6.0)
	_streams["react_oops"] = _stream(b)

	# Sad: the classic falling "wah-wah".
	b = _buf(1.0)
	_sweep(b, 0.0, 400.0, 330.0, 0.35, 0.36, 3.5)
	_sweep(b, 0.35, 340.0, 230.0, 0.55, 0.36, 3.0)
	_streams["react_sad"] = _stream(b)

	# Angry: a low buzzing growl.
	b = _buf(0.55)
	_sweep(b, 0.0, 150.0, 110.0, 0.45, 0.4, 3.0)
	_sweep(b, 0.0, 300.0, 215.0, 0.45, 0.2, 3.5)
	_noise(b, 0.0, 0.35, 0.12, 6.0, 0.2)
	_streams["react_angry"] = _stream(b)

	# Hurry up: ticking, then an alarm-clock ring.
	b = _buf(1.0)
	for i in 4:
		_noise(b, 0.12 * float(i), 0.03, 0.4, 70.0, 0.6)
		_tone(b, 0.12 * float(i), 1500.0, 0.03, 0.18, 70.0)
	for i in 6:
		_tone(b, 0.5 + 0.075 * float(i), 1760.0 if i % 2 == 0 else 1480.0, 0.07, 0.28, 18.0, [1.0, 0.4])
	_streams["react_hurry"] = _stream(b)


# ---------------------------------------------------------------- synthesis helpers

func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


## A sine tone (with optional overtones) with a fast attack and exponential decay.
func _tone(buf: PackedFloat32Array, start: float, freq: float, dur: float, amp: float, decay: float, partials: Array = [1.0]) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var norm := 0.0
	for p in partials:
		norm += float(p)
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		var env := exp(-decay * t) * minf(1.0, t / 0.004)
		var v := 0.0
		for k in partials.size():
			v += float(partials[k]) * sin(TAU * freq * float(k + 1) * t)
		buf[idx] += amp * env * v / norm


## Low-passed white noise with exponential decay (`lowpass` 0..1: smaller = darker).
func _noise(buf: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, lowpass: float) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var lp := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		lp += (_rng.randf() * 2.0 - 1.0 - lp) * lowpass
		buf[idx] += amp * exp(-decay * t) * minf(1.0, t / 0.003) * lp


func _sweep(buf: PackedFloat32Array, start: float, f0: float, f1: float, dur: float, amp: float, decay: float) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var f := lerpf(f0, f1, float(i) / float(n))
		phase += TAU * f / RATE
		var t := float(i) / RATE
		buf[idx] += amp * exp(-decay * t) * minf(1.0, t / 0.004) * sin(phase)


func _stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

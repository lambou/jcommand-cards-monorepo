extends SceneTree
## Decodes the Joker roar MP3 to a raw 32-bit float stereo file (for numpy) and prints its length / rate.
## godot --headless --path apps/mobile -s <this file>

func _init() -> void:
	var src := "res://assets/joker/soundzee-lion-snarl-growl-354324.mp3"
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes(src)
	var length := stream.get_length()
	print("length s: ", length, "  mix rate: ", AudioServer.get_mix_rate())
	var pb := stream.instantiate_playback()
	pb.start(0.0)
	var rate := int(AudioServer.get_mix_rate())
	var total := int(ceil(length * rate)) + 2048
	var out := PackedFloat32Array()
	var left := total
	while left > 0:
		var n := mini(left, 4096)
		var frames: PackedVector2Array = pb.mix_audio(1.0, n)
		if frames.size() == 0:
			break
		for f in frames:
			out.append(f.x)
			out.append(f.y)
		left -= frames.size()
	print("decoded frames: ", out.size() / 2)
	var fa := FileAccess.open("D:/develop/games/jcommand-cards-game/tools/audio/_roar_raw.f32", FileAccess.WRITE)
	fa.store_buffer(out.to_byte_array())
	fa.close()
	print("rate=", rate)
	quit()

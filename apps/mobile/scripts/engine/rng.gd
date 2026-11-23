extends RefCounted
## mulberry32, bit-for-bit identical to packages/engine/src/rng.ts.
## All arithmetic is kept as unsigned 32-bit values via masking.

const M := 0xFFFFFFFF


## box is {"s": int}; returns a float in [0, 1).
static func next_random(box: Dictionary) -> float:
	box["s"] = (int(box["s"]) + 0x6D2B79F5) & M
	var t: int = box["s"]
	t = ((t ^ (t >> 15)) * (t | 1)) & M
	var mixed: int = ((t ^ (t >> 7)) * (t | 61)) & M
	t = (t ^ ((t + mixed) & M)) & M
	return float((t ^ (t >> 14)) & M) / 4294967296.0


static func shuffle_in_place(arr: Array, box: Dictionary) -> void:
	var i := arr.size() - 1
	while i > 0:
		var j := int(floor(next_random(box) * (i + 1)))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		i -= 1

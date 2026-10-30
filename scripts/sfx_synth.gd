class_name SfxSynth
## Renders the prototype's Web Audio sound effects (the `sfx` object in
## highnoon.html) into AudioStreamWAVs once at startup, so the port sounds the
## same without sample files. Recorded samples can replace these later.

const RATE := 22050


const NAMES := ["shot", "enemy_shot", "thunk", "glass", "down", "boom", "crash", "miss", "ping",
	"card", "tick", "cock", "clank", "twitch", "bell", "win", "lose", "thump", "rustle", "creak", "tick2", "flip"]


static func build_all() -> Dictionary:
	var out := {}
	for key in NAMES:
		out[key] = _to_wav(_render(key))
	return out


static func _render(key: String) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	match key:
		"shot":
			b = _noise(b, 0.25, 4000, 200, 0.35)
			b = _tone(b, 140, 50, 0.15, "square", 0.06)
		"enemy_shot":
			b = _noise(b, 0.3, 2500, 150, 0.22, 0.02)
			b = _tone(b, 110, 45, 0.2, "sawtooth", 0.05)
		"thunk":
			b = _tone(b, 220, 90, 0.08, "triangle", 0.12)
			b = _noise(b, 0.06, 1800, 400, 0.08)
		"glass":
			b = _tone(b, 2400, 1800, 0.08, "triangle", 0.05)
			b = _tone(b, 3100, 2600, 0.1, "triangle", 0.04, 0.03)
			b = _noise(b, 0.15, 8000, 3000, 0.06)
		"down":
			b = _tone(b, 300, 120, 0.25, "square", 0.04)
		"boom":
			b = _noise(b, 1.1, 1500, 60, 0.5)
			b = _tone(b, 70, 30, 0.8, "sine", 0.2)
		"crash":
			b = _noise(b, 0.5, 1200, 100, 0.3)
			b = _tone(b, 120, 60, 0.3, "triangle", 0.1)
		"miss":
			b = _tone(b, 2600, 800, 0.2, "sine", 0.03)
			b = _noise(b, 0.05, 5000, 2000, 0.05)
		"ping":
			b = _tone(b, 3400, 2600, 0.14, "triangle", 0.06)
			b = _tone(b, 5200, 4800, 0.06, "sine", 0.02)
		"card":
			b = _noise(b, 0.06, 6000, 2500, 0.08)
		"tick":
			for i in 3:
				b = _tone(b, 1900, 1700, 0.03, "square", 0.035, i * 0.09)
		"cock":
			b = _tone(b, 700, 450, 0.06, "square", 0.05)
			b = _noise(b, 0.05, 4000, 1500, 0.06)
		"clank":
			b = _tone(b, 900, 500, 0.12, "square", 0.05)
			b = _noise(b, 0.15, 3000, 600, 0.12)
		"twitch":
			b = _tone(b, 200, 180, 0.05, "triangle", 0.05)
		"bell":
			b = _tone(b, 1320, 1310, 0.9, "sine", 0.08)
			b = _tone(b, 1980, 1970, 0.6, "sine", 0.03)
		"win":
			b = _whistle(b, [[587, .18], [784, .18], [880, .36], [784, .18], [988, .5]])
		"lose":
			b = _whistle(b, [[523, .25], [466, .25], [392, .6]])
		"thump":
			b = _tone(b, 120, 60, 0.15, "triangle", 0.12)
			b = _noise(b, 0.08, 900, 200, 0.12)
		"rustle":
			b = _noise(b, 0.18, 3500, 1200, 0.12)
			b = _noise(b, 0.12, 2500, 900, 0.08, 0.08)
		"creak":
			b = _tone(b, 160, 110, 0.32, "sawtooth", 0.03, 0, 18)
			b = _tone(b, 240, 180, 0.2, "triangle", 0.025, 0.05, 10)
		"tick2":
			b = _tone(b, 2600, 2400, 0.05, "square", 0.03)
		"flip":
			b = _noise(b, 0.07, 5000, 2000, 0.09)
			b = _noise(b, 0.06, 4500, 1800, 0.06, 0.07)
	return b


static func _ensure(buf: PackedFloat32Array, end: int) -> PackedFloat32Array:
	if buf.size() < end:
		buf.resize(end)
	return buf


## An oscillator with an exponential pitch glide and the prototype's envelope
## (20 ms linear attack, then an exponential fall to silence).
static func _tone(buf: PackedFloat32Array, f1: float, f2: float, d: float, type := "square", vol := 0.04, delay := 0.0, vib := 0.0) -> PackedFloat32Array:
	var start := int(delay * RATE)
	var n := int(d * RATE)
	buf = _ensure(buf, start + n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f1 * pow(f2 / f1, t / d)
		if vib > 0.0:
			f += sin(TAU * 6.0 * t) * vib
		phase = fmod(phase + f / RATE, 1.0)
		var w: float
		match type:
			"square": w = 1.0 if phase < 0.5 else -1.0
			"triangle": w = 4.0 * absf(phase - 0.5) - 1.0
			"sawtooth": w = 2.0 * phase - 1.0
			_: w = sin(TAU * phase)
		var env := vol * t / 0.02 if t < 0.02 else vol * pow(0.0001 / vol, (t - 0.02) / maxf(0.001, d - 0.02))
		buf[start + i] += w * env
	return buf


## White noise through a low-pass whose cutoff glides from f1 to f2.
static func _noise(buf: PackedFloat32Array, d: float, f1: float, f2: float, vol: float, delay := 0.0) -> PackedFloat32Array:
	var start := int(delay * RATE)
	var n := int(d * RATE)
	buf = _ensure(buf, start + n)
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var fc := minf(f1 * pow(f2 / f1, t / d), RATE * 0.45)
		var a := 1.0 - exp(-TAU * fc / RATE)
		y1 += a * (randf() * 2.0 - 1.0 - y1)
		y2 += a * (y1 - y2)  # two poles, close to the prototype's biquad slope
		buf[start + i] += y2 * vol * pow(0.0001 / vol, t / d) * 1.6
	return buf


static func _whistle(buf: PackedFloat32Array, notes: Array) -> PackedFloat32Array:
	var t := 0.0
	for nd in notes:
		buf = _tone(buf, nd[0], nd[0] * 1.001, nd[1], "sine", 0.06, t, 8)
		t += nd[1]
	return buf


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * 1.4, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s

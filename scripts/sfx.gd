extends RefCounted
## Procedurally synthesised sound effects (no audio files needed).

const RATE := 22050


static func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


static func make(name: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	match name:
		"thunder":
			return _thunder(rng)
		"rain":
			return _rain(rng)
		"hit":
			return _hit(rng)
		"swing":
			return _swing(rng)
		"bolt":
			return _bolt(rng)
		"chime":
			return _chime()
		"potion":
			return _potion()
		"roar":
			return _roar(rng)
		"hurt":
			return _hurt(rng)
	if name.begins_with("v") and name.length() == 2:
		return _voice(int(name.substr(1)), 0)
	if name.begins_with("h") and name.length() == 2:
		return _voice(int(name.substr(1)), 1)
	if name.begins_with("m") and name.length() == 2:
		return _voice(int(name.substr(1)), 2)
	if name == "boom":
		return _boom(rng)
	if name == "crumble":
		return _crumble(rng)
	return _hit(rng)


static func _thunder(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 3.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		var a := lerpf(0.55, 0.02, clampf(t / 0.6, 0.0, 1.0))
		lp += (white - lp) * a
		lp2 += (lp - lp2) * 0.25
		var env := exp(-t * 1.25) * (0.55 + 0.45 * sin(t * 6.5 + 1.3 * sin(t * 2.1)))
		var crack := exp(-t * 28.0) * white * 0.9
		s[i] = (lp2 * 4.2 * env + crack) * minf(t / 0.01, 1.0)
	return _wav(s)


static func _rain(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var fade := 800
	var total := RATE * 2 + fade
	var raw := PackedFloat32Array()
	raw.resize(total)
	var lp := 0.0
	for i in total:
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.35
		raw[i] = (white - lp) * 0.22 + lp * 0.1
	# cross-fade the tail into the head so the loop has no click
	var n := RATE * 2
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = raw[i]
	for i in fade:
		var k := float(i) / fade
		s[i] = raw[i] * k + raw[n + i] * (1.0 - k)
	return _wav(s, true)


static func _hit(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.3
		s[i] = (lp * exp(-t * 22.0) * 1.2 + sin(t * TAU * 110.0) * exp(-t * 26.0) * 0.8)
	return _wav(s)


static func _hurt(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.15
		s[i] = lp * exp(-t * 14.0) * 1.6 + sin(t * TAU * 70.0) * exp(-t * 15.0) * 0.9
	return _wav(s)


static func _swing(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / 0.28
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * lerpf(0.05, 0.5, sin(u * PI))
		s[i] = lp * sin(u * PI) * 0.7
	return _wav(s)


static func _bolt(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 1.1)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.2
		s[i] = (white * exp(-t * 30.0) * 0.9 + lp * exp(-t * 5.0) * 1.6) * minf(t / 0.004, 1.0)
	return _wav(s)


static func _chime() -> AudioStreamWAV:
	var n := int(RATE * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var t0: float = k * 0.11
			if t > t0:
				v += sin((t - t0) * TAU * float(notes[k])) * exp(-(t - t0) * 3.2) * 0.3
		s[i] = v
	return _wav(s)


static func _potion() -> AudioStreamWAV:
	var n := int(RATE * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(300.0, 900.0, t / 0.7)
		s[i] = sin(t * TAU * f) * sin(t / 0.7 * PI) * 0.35 + sin(t * TAU * f * 1.5) * sin(t / 0.7 * PI) * 0.12
	return _wav(s)


static func _roar(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 1.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 62.0 + sin(t * 9.0) * 8.0 - t * 12.0
		var saw := fmod(t * f, 1.0) * 2.0 - 1.0
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.12
		var env := sin(clampf(t / 1.6, 0.0, 1.0) * PI) * 0.9
		s[i] = (saw * 0.5 + lp * 0.9) * env
	return _wav(s)


const FORMANTS := [[700.0, 1200.0], [450.0, 800.0], [500.0, 1900.0], [350.0, 700.0]]


## One short spoken syllable. style 0 = guttural growl, 1 = hissing, 2 = cold metallic. Play with a low pitch_scale for bigger voices.
static func _voice(vowel: int, style: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = vowel * 31 + style * 7 + 5
	var dur := 0.13
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var fm: Array = FORMANTS[vowel % FORMANTS.size()]
	var f0 := 105.0 + rng.randf_range(-8.0, 8.0)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f0 * (1.0 - 0.15 * t / dur)
		var v := 0.0
		for k in range(1, 18):
			var hf := f * k
			var amp := exp(-pow((hf - float(fm[0])) / 220.0, 2.0)) + 0.6 * exp(-pow((hf - float(fm[1])) / 320.0, 2.0))
			v += sin(t * TAU * hf) * amp / float(k) * 2.2
		var noise := rng.randf_range(-1.0, 1.0)
		var env := minf(t / 0.012, 1.0) * clampf((dur - t) / 0.05, 0.0, 1.0)
		match style:
			0:
				v = v * (0.75 + 0.25 * sign(sin(t * TAU * 38.0))) + noise * 0.08
			1:
				lp += (noise - lp) * 0.55
				v = v * 0.35 + (noise - lp) * 0.7
			_:
				v = v * sin(t * TAU * 90.0 + 1.0) * 1.4 + sin(t * TAU * 620.0) * 0.12
		s[i] = clampf(v, -1.0, 1.0) * env * 0.5
	return _wav(s)


## Deep explosion: pressure thump, falling sine and a rumbling noise tail.
static func _boom(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 2.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * lerpf(0.5, 0.04, clampf(t / 0.8, 0.0, 1.0))
		var thump := sin(t * TAU * (95.0 - 60.0 * clampf(t / 0.6, 0.0, 1.0))) * exp(-t * 2.4)
		s[i] = (thump * 0.8 + lp * 0.9 * exp(-t * 1.6)) * minf(t / 0.004, 1.0)
	return _wav(s)


## Stone / armour crumbling: sparse clacks over a fading rumble.
static func _crumble(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(RATE * 1.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var click := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.08
		if rng.randf() < 0.0018 * (1.0 - t / 1.8):
			click = rng.randf_range(0.5, 1.0)
		click *= 0.985
		s[i] = (lp * 0.7 + white * click * 0.5) * (1.0 - t / 1.8)
	return _wav(s)

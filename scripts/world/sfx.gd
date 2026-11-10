class_name Sfx
extends Node
## Procedural sound bank. Every sound is synthesised at startup (no audio assets), then
## played through a small pool of players. Loops (jetpack, laser, ambience) have their own player.

const RATE := 22050

var bank: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var loops: Dictionary = {}
var master := 0.0


func _ready() -> void:
	# Master-bus limiter so overlapping sounds never clip (clipping is what crackles).
	var bus := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		lim.pre_gain_db = -3.0
		AudioServer.add_bus_effect(bus, lim)
	_build()
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for n in ["jet", "laser", "ambient", "rover", "storm"]:
		var lp := AudioStreamPlayer.new()
		lp.stream = bank[n]
		lp.volume_db = -80.0
		add_child(lp)
		loops[n] = lp


func play(name: String, vol_db := 0.0, pitch := 1.0, rand_pitch := 0.08) -> void:
	if not bank.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = bank[name]
	p.volume_db = vol_db + master
	p.pitch_scale = pitch * (1.0 + randf_range(-rand_pitch, rand_pitch))
	p.play()


func play_at(name: String, pos: Vector3, listener: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	var d := pos.distance_to(listener)
	if d > 40.0:
		return
	play(name, vol_db - d * 0.6, pitch)


## Fade a loop toward a target volume (call every frame).
func loop(name: String, on: bool, vol_db := -6.0, pitch := 1.0, dt := 0.016) -> void:
	var lp: AudioStreamPlayer = loops.get(name)
	if lp == null:
		return
	var target := (vol_db + master) if on else -60.0
	lp.volume_db = move_toward(lp.volume_db, target, dt * 120.0)
	lp.pitch_scale = lerpf(lp.pitch_scale, pitch, dt * 4.0)
	if lp.volume_db > -59.0 and not lp.playing:
		lp.play()
	elif lp.volume_db <= -59.0 and lp.playing:
		lp.stop()


# ---------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array, looped := false, peak := 0.55) -> AudioStreamWAV:
	# normalise every sound to the same peak, with a short fade-out so nothing ends in a click
	var mx := 0.0001
	for s in samples:
		mx = maxf(mx, absf(s))
	var g := peak / mx
	var n := samples.size()
	var tail := mini(220, n / 4)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := samples[i] * g
		if not looped and i > n - tail:
			v *= float(n - i) / tail
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _noise_burst(sec: float, cutoff: float, decay: float, gain := 1.0) -> PackedFloat32Array:
	# two-pole low-passed noise with a 4 ms attack (no click at the start)
	var b := _buf(sec)
	var lp := 0.0
	var lp2 := 0.0
	var a := clampf(cutoff, 0.001, 1.0)
	for i in b.size():
		var t := i / float(RATE)
		lp += (randf_range(-1, 1) - lp) * a
		lp2 += (lp - lp2) * a
		b[i] = lp2 * minf(t / 0.004, 1.0) * exp(-t * decay) * gain
	return b


func _tone(sec: float, f0: float, f1: float, decay: float, shape := "sine", gain := 0.6) -> PackedFloat32Array:
	var b := _buf(sec)
	var ph := 0.0
	for i in b.size():
		var t := i / float(RATE)
		var f := lerpf(f0, f1, t / sec)
		ph += f / RATE
		var s := 0.0
		match shape:
			"sine": s = sin(ph * TAU)
			"square": s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"saw": s = fmod(ph, 1.0) * 2.0 - 1.0
			"tri": s = absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
		var env := minf(t * 400.0, 1.0) * exp(-t * decay)
		b[i] = s * env * gain
	return b


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gb := 1.0) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		o[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0) * gb
	return o


func _concat(parts: Array) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	for p in parts:
		o.append_array(p)
	return o


func _build() -> void:
	seed(7)
	bank["dig"] = _wav(_mix(_noise_burst(0.07, 0.3, 55.0, 0.5), _tone(0.08, 260, 120, 50, "tri", 0.6)), false, 0.4)
	bank["break"] = _wav(_mix(_mix(_noise_burst(0.3, 0.18, 13.0, 0.7), _tone(0.28, 150, 55, 16, "sine", 0.9)), _concat([_buf(0.05), _noise_burst(0.18, 0.4, 22.0, 0.35)])), false, 0.55)
	bank["break_crystal"] = _wav(_mix(_noise_burst(0.3, 0.7, 12.0, 0.4), _mix(_tone(0.5, 1600, 1500, 7, "sine", 0.35), _tone(0.5, 2400, 2350, 9, "sine", 0.25))))
	bank["place"] = _wav(_mix(_noise_burst(0.07, 0.5, 60.0, 0.6), _tone(0.08, 220, 110, 50, "sine", 0.6)))
	bank["step"] = _wav(_mix(_noise_burst(0.07, 0.08, 60.0, 0.6), _tone(0.06, 110, 70, 60, "sine", 0.4)), false, 0.3)
	bank["jump"] = _wav(_tone(0.12, 220, 420, 22, "tri", 0.35))
	bank["land"] = _wav(_mix(_noise_burst(0.12, 0.15, 30.0, 0.9), _tone(0.12, 90, 40, 25, "sine", 0.8)))
	bank["shoot"] = _wav(_mix(_tone(0.18, 1400, 180, 18, "saw", 0.4), _noise_burst(0.1, 0.8, 40.0, 0.25)))
	bank["shoot_heavy"] = _wav(_mix(_tone(0.45, 600, 60, 7, "square", 0.35), _noise_burst(0.4, 0.3, 9.0, 0.6)))
	bank["swing"] = _wav(_noise_burst(0.18, 0.6, 18.0, 0.5))
	bank["hit"] = _wav(_mix(_tone(0.1, 320, 160, 35, "square", 0.3), _noise_burst(0.08, 0.6, 50.0, 0.5)))
	bank["hurt"] = _wav(_mix(_tone(0.25, 300, 90, 12, "saw", 0.45), _noise_burst(0.15, 0.3, 25.0, 0.4)))
	bank["pickup"] = _wav(_concat([_tone(0.06, 880, 880, 30, "sine", 0.4), _tone(0.1, 1320, 1320, 25, "sine", 0.4)]))
	bank["craft"] = _wav(_concat([_tone(0.08, 523, 523, 20, "tri", 0.4), _tone(0.08, 659, 659, 20, "tri", 0.4), _tone(0.16, 784, 784, 12, "tri", 0.45)]))
	bank["ui"] = _wav(_tone(0.04, 1200, 900, 80, "sine", 0.35))
	bank["quest"] = _wav(_concat([_tone(0.12, 392, 392, 10, "tri", 0.4), _tone(0.12, 523, 523, 10, "tri", 0.4), _tone(0.3, 784, 784, 5, "tri", 0.45)]))
	bank["call_low"] = _wav(_fm(0.45, 160, 5.0, 0.6, 6.0))
	bank["call_high"] = _wav(_fm(0.3, 720, 9.0, 0.4, 10.0))
	bank["growl"] = _wav(_mix(_fm(0.5, 90, 23.0, 0.8, 5.0), _noise_burst(0.5, 0.1, 5.0, 0.5)))
	bank["die"] = _wav(_mix(_tone(0.5, 500, 60, 6, "saw", 0.35), _noise_burst(0.3, 0.2, 10.0, 0.3)))
	bank["explode"] = _wav(_mix(_noise_burst(0.9, 0.12, 4.5, 1.0), _tone(0.8, 70, 30, 5, "sine", 0.9)))
	bank["whoosh"] = _wav(_whoosh(1.2))
	bank["warp"] = _wav(_mix(_tone(1.6, 80, 900, 1.5, "saw", 0.3), _whoosh(1.6)))
	bank["jet"] = _wav(_jet_loop(1.0), true, 0.35)
	bank["laser"] = _wav(_laser_loop(0.5), true, 0.3)
	bank["ambient"] = _wav(_ambient_loop(6.0), true, 0.18)
	bank["rover"] = _wav(_engine_loop(0.5), true, 0.4)
	bank["storm"] = _wav(_wind_loop(4.0, 0.012), true, 0.3)


func _fm(sec: float, f: float, mod_f: float, depth: float, decay: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var ph := 0.0
	for i in b.size():
		var t := i / float(RATE)
		var ff := f * (1.0 + depth * sin(TAU * mod_f * t))
		ph += ff / RATE
		var env := minf(t * 40.0, 1.0) * exp(-t * decay)
		b[i] = sin(ph * TAU) * env * 0.5
	return b


func _whoosh(sec: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var lp := 0.0
	for i in b.size():
		var t := i / float(RATE)
		var k := sin(PI * t / sec)
		lp += (randf_range(-1, 1) - lp) * (0.03 + 0.2 * k)
		b[i] = lp * k * 1.2
	return b


func _loop_noise(sec: float, cutoff: float, gain: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var lp := 0.0
	for i in b.size():
		lp += (randf_range(-1, 1) - lp) * cutoff
		b[i] = lp * gain
	# crossfade ends for a seamless loop
	var n := 800
	for i in n:
		var w := i / float(n)
		b[i] = b[i] * w + b[b.size() - n + i] * (1.0 - w)
	return b.slice(0, b.size() - n)


func _laser_loop(sec: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var f := 220.0
	var cycles := int(f * sec)
	f = cycles / sec
	for i in b.size():
		var t := i / float(RATE)
		var s := fmod(t * f, 1.0) * 2.0 - 1.0
		var w := sin(TAU * (2.0 / sec) * t) * 0.3
		b[i] = (s * 0.25 + sin(TAU * f * 2.0 * t) * 0.15) * (0.8 + w)
	return b


func _engine_loop(sec: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var f := 60.0
	for i in b.size():
		var t := i / float(RATE)
		b[i] = (sin(TAU * f * t) * 0.4 + sin(TAU * f * 2.0 * t) * 0.2 + randf_range(-0.1, 0.1)) * 0.6
	return b


## Soft wind: very low-passed noise with slow gusts. Loop-safe (gust LFO completes whole cycles).
func _wind_loop(sec: float, cutoff: float) -> PackedFloat32Array:
	var b := _loop_noise(sec, cutoff, 1.0)
	var n := b.size()
	var dur := n / float(RATE)
	for i in n:
		var t := i / float(RATE)
		var gust := 0.55 + 0.3 * sin(TAU * t / dur) + 0.15 * sin(TAU * 3.0 * t / dur)
		b[i] *= gust
	return b


func _ambient_loop(sec: float) -> PackedFloat32Array:
	var b := _wind_loop(sec, 0.006)
	var n := b.size()
	var dur := n / float(RATE)
	# a faint alien hum on top, at loop-aligned frequencies
	var f1: float = roundf(55.0 * dur) / dur
	var f2: float = roundf(82.5 * dur) / dur
	for i in n:
		var t := i / float(RATE)
		b[i] = b[i] * 0.8 + (sin(TAU * f1 * t) * 0.05 + sin(TAU * f2 * t) * 0.03) * (0.6 + 0.4 * sin(TAU * t / dur))
	return b


func _jet_loop(sec: float) -> PackedFloat32Array:
	var b := _loop_noise(sec, 0.07, 1.0)
	var n := b.size()
	var dur := n / float(RATE)
	var f: float = roundf(70.0 * dur) / dur
	for i in n:
		var t := i / float(RATE)
		b[i] = b[i] * 0.7 + sin(TAU * f * t) * 0.18 + sin(TAU * f * 2.0 * t) * 0.06
	return b

class_name Music
extends Node
## Generative soundtrack. Two seamless loops (day / night) are synthesised on a background
## thread from chord progressions: detuned saw pads through a low-pass filter, a plucked
## arpeggio, sub bass and bells, with a circular echo so the loop wraps without a seam.
## Crossfades by daylight. No audio files.

const RATE := 22050

var day_player := AudioStreamPlayer.new()
var night_player := AudioStreamPlayer.new()
var daylight := 1.0
var volume := 0.7
var _thread: Thread
var _ready_streams: Array = []
var _mutex := Mutex.new()
var _started := false


func _ready() -> void:
	for p in [day_player, night_player]:
		p.volume_db = -80.0
		add_child(p)
	_thread = Thread.new()
	_thread.start(_render_all)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _render_all() -> void:
	var day := _render({"bpm": 76, "root": 50, "chords": [[0, 3, 7, 10, 14], [-4, 0, 3, 7, 11], [-9, -5, 0, 4, 7], [-2, 2, 5, 9, 12]], "arp": [0, 2, 4, 3, 1, 3, 2, 4], "bright": 1.0, "seed": 11})
	_mutex.lock()
	_ready_streams.append(["day", day])
	_mutex.unlock()
	var night := _render({"bpm": 60, "root": 45, "chords": [[0, 3, 7, 12, 15], [-4, 0, 3, 7, 10], [-7, -3, 0, 5, 9], [-5, -1, 2, 7, 11]], "arp": [0, 4, 2, 3, 1, 4, 2, 0], "bright": 0.6, "seed": 23})
	_mutex.lock()
	_ready_streams.append(["night", night])
	_mutex.unlock()


static func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


func _render(cfg: Dictionary) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = cfg.seed
	var beat := 60.0 / float(cfg.bpm)
	var bars_per_chord := 2
	var chords: Array = cfg.chords
	var total_beats := chords.size() * bars_per_chord * 4
	var n := int(total_beats * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var root: float = cfg.root
	# --- pads
	var chord_len := int(bars_per_chord * 4 * beat * RATE)
	for ci in chords.size():
		var ch: Array = chords[ci]
		var start := ci * chord_len
		var span := int(chord_len * 1.25)
		for k in 3:
			var f := _freq(root + 12 + float(ch[k]))
			var ph1 := rng.randf()
			var ph2 := rng.randf()
			var lp := 0.0
			for i in span:
				var t := i / float(RATE)
				var env := minf(t / 1.8, 1.0) * clampf((span - i) / (RATE * 2.0), 0.0, 1.0)
				ph1 = fmod(ph1 + f / RATE, 1.0)
				ph2 = fmod(ph2 + f * 1.006 / RATE, 1.0)
				var s := (ph1 * 2.0 - 1.0) + (ph2 * 2.0 - 1.0)
				var cut := 0.035 + 0.025 * sin(TAU * t / 9.0) * float(cfg.bright)
				lp += (s - lp) * cut
				buf[(start + i) % n] += lp * env * 0.055
	# --- bass
	for ci in chords.size():
		var ch: Array = chords[ci]
		for half in bars_per_chord * 2:
			var start := ci * chord_len + int(half * 2 * beat * RATE)
			var f := _freq(root - 12 + float(ch[0]))
			var len := int(beat * 1.9 * RATE)
			var ph := 0.0
			for i in len:
				var t := i / float(RATE)
				ph += f / RATE
				var env := minf(t * 30.0, 1.0) * exp(-t * 1.6)
				buf[(start + i) % n] += (sin(ph * TAU) + 0.25 * sin(ph * TAU * 2.0)) * env * 0.16
	# --- arpeggio (eighth notes)
	var pattern: Array = cfg.arp
	var steps := total_beats * 2
	for s in steps:
		if rng.randf() < 0.18:
			continue
		var ci := int(s / (bars_per_chord * 8)) % chords.size()
		var ch: Array = chords[ci]
		var tone: int = ch[int(pattern[s % pattern.size()]) % ch.size()]
		var octave := 24 if (s % 16) >= 8 and rng.randf() < 0.5 else 12
		var f := _freq(root + octave + tone)
		var start := int(s * beat * 0.5 * RATE)
		var vel := rng.randf_range(0.6, 1.0)
		var len := int(RATE * 1.2)
		var ph := 0.0
		for i in len:
			var t := i / float(RATE)
			ph += f / RATE
			var env := minf(t * 200.0, 1.0) * exp(-t * 4.5)
			var v := sin(ph * TAU) + 0.3 * sin(ph * TAU * 2.0) * exp(-t * 9.0) + 0.12 * sin(ph * TAU * 3.0) * exp(-t * 14.0)
			buf[(start + i) % n] += v * env * 0.075 * vel
	# --- bells
	for b in 6:
		var start := int(rng.randf() * n)
		var ch: Array = chords[int(start / chord_len) % chords.size()]
		var f := _freq(root + 36 + float(ch[rng.randi() % ch.size()]))
		var len := int(RATE * 3.0)
		var ph := 0.0
		for i in len:
			var t := i / float(RATE)
			ph += f / RATE
			var env := minf(t * 300.0, 1.0) * exp(-t * 1.4)
			buf[(start + i) % n] += (sin(ph * TAU) + 0.4 * sin(ph * TAU * 2.76)) * env * 0.04
	# --- circular echo
	var d := int(beat * 0.75 * RATE)
	var echo := buf.duplicate()
	for pass_i in 3:
		var g := 0.32 * pow(0.6, pass_i)
		var off := d * (pass_i + 1)
		for i in n:
			echo[(i + off) % n] += buf[i] * g
	# --- normalise and encode
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(echo[i]))
	var gain := 0.85 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(echo[i] * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _process(dt: float) -> void:
	_mutex.lock()
	var got := _ready_streams
	_ready_streams = []
	_mutex.unlock()
	for r in got:
		var p := day_player if r[0] == "day" else night_player
		p.stream = r[1]
		p.play()
	var base := linear_to_db(maxf(volume * float(Game.settings.get("ambience", 0.7)), 0.0001)) - 6.0
	var dw := clampf(daylight, 0.0, 1.0)
	_fade(day_player, base + linear_to_db(maxf(dw, 0.0001)), dt)
	_fade(night_player, base + linear_to_db(maxf(1.0 - dw, 0.0001)), dt)


func _fade(p: AudioStreamPlayer, target: float, dt: float) -> void:
	if p.stream == null:
		return
	p.volume_db = move_toward(p.volume_db, maxf(target, -60.0), dt * 18.0)

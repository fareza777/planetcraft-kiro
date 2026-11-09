extends RefCounted
## Procedural pixel-art generator. Every block tile and item icon in PlanetCraft is drawn
## here from the recipes in data/tiles.json and data/items.json, so the game ships no
## third-party texture assets.

const S := 32


# ---------------------------------------------------------------- helpers

static func _cols(arr: Array) -> Array[Color]:
	var out: Array[Color] = []
	for c in arr:
		out.append(Color.html(c))
	return out


static func _h(x: int, y: int, s: int) -> float:
	var n: int = (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


static func _noise(seed: int, freq: float, octaves: int = 3) -> PackedFloat32Array:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(S, S, false, false, 0.1, true)
	var out := PackedFloat32Array()
	out.resize(S * S)
	for y in S:
		for x in S:
			out[y * S + x] = img.get_pixel(x, y).r
	return out


static func _pal(cols: Array[Color], t: float) -> Color:
	var i := clampi(int(t * cols.size()), 0, cols.size() - 1)
	return cols[i]


static func _blank() -> Image:
	return Image.create_empty(S, S, false, Image.FORMAT_RGBA8)


static func _wrapd(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, S - d)


static func _voronoi(x: int, y: int, pts: Array) -> Vector3:
	# returns (d1, d2, index of nearest)
	var d1 := 1e9
	var d2 := 1e9
	var idx := 0
	for i in pts.size():
		var p: Vector2 = pts[i]
		var dx := _wrapd(x + 0.5, p.x)
		var dy := _wrapd(y + 0.5, p.y)
		var d := sqrt(dx * dx + dy * dy)
		if d < d1:
			d2 = d1
			d1 = d
			idx = i
		elif d < d2:
			d2 = d
	return Vector3(d1, d2, idx)


static func _rand_pts(n: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := []
	for i in n:
		pts.append(Vector2(rng.randf() * S, rng.randf() * S))
	return pts


# ---------------------------------------------------------------- tiles

static func make_tile(def: Dictionary, seed: int, base: Image) -> Image:
	var cols := _cols(def.get("c", ["#ff00ff"]))
	var img := _blank()
	if base != null:
		img.copy_from(base)
	var p: String = def.get("pattern", "noise")
	match p:
		"noise": _p_noise(img, cols, seed, def.get("f", 0.2), def.get("spots", 0.0))
		"strata": _p_strata(img, cols, seed, def.get("f", 0.12))
		"grass_top": _p_grass_top(img, cols, seed, def.get("f", 0.2))
		"grass_side": _p_grass_side(img, cols, seed, base != null)
		"ore": _p_ore(img, cols, seed, int(def.get("n", 5)), base != null)
		"log_side": _p_log_side(img, cols, seed)
		"log_top": _p_log_top(img, cols, seed)
		"leaves": _p_leaves(img, cols, seed, Color.html(def.get("glow", "#ffffff")))
		"crystal": _p_crystal(img, cols, seed)
		"ice": _p_ice(img, cols, seed)
		"magma": _p_magma(img, cols, seed)
		"brick": _p_brick(img, cols, seed, Color.html(def.get("mortar", "#202020")))
		"glyph": _p_glyph(img, seed, Color.html(def.get("glow", "#4fe3ff")), def.get("frame", false))
		"metal": _p_metal(img, cols, seed, def)
		"machine": _p_machine(img, cols, seed, def)
		"solar": _p_solar(img, cols, seed)
		"cable": _p_cable(img, cols, seed, Color.html(def.get("accent", "#ffcc33")))
		"crate": _p_crate(img, cols, seed, Color.html(def.get("accent", "#e8b23a")))
		"hydro": _p_hydro(img, cols, seed)
		"conveyor": _p_conveyor(img, cols, seed, Color.html(def.get("accent", "#ffb02e")))
		"soil": _p_soil(img, cols, seed)
		"hive": _p_hive(img, cols, seed, Color.html(def.get("accent", "#ff4ab0")))
		"glass": _p_glass(img, cols)
		"lamp": _p_lamp(img, cols)
		"water": _p_water(img, cols, seed)
		"plant": _p_plant(img, cols, seed, def.get("shape", "blades"))
		_: _p_noise(img, cols, seed, 0.2, 0.0)
	return img


static func _p_noise(img: Image, cols: Array[Color], seed: int, f: float, spots: float) -> void:
	var n := _noise(seed, f)
	for y in S:
		for x in S:
			var t := n[y * S + x] + (_h(x, y, seed) - 0.5) * 0.14
			var c := _pal(cols, t)
			if spots > 0.0 and _h(x, y, seed + 1) < spots:
				c = c.darkened(0.3)
			img.set_pixel(x, y, c)


static func _p_strata(img: Image, cols: Array[Color], seed: int, f: float) -> void:
	var n := _noise(seed, f)
	var n2 := _noise(seed + 5, 0.08, 2)
	for y in S:
		for x in S:
			var band := sin((y + n2[y * S + x] * 5.0) * TAU / 8.0) * 0.5 + 0.5
			var t := n[y * S + x] * 0.55 + band * 0.4 + (_h(x, y, seed) - 0.5) * 0.1
			img.set_pixel(x, y, _pal(cols, t))


static func _p_grass_top(img: Image, cols: Array[Color], seed: int, f: float) -> void:
	_p_noise(img, cols, seed, f, 0.0)
	for y in S:
		for x in S:
			var h := _h(x, y, seed + 9)
			if h < 0.07:
				img.set_pixel(x, y, cols[cols.size() - 1])
			elif h < 0.12:
				img.set_pixel(x, y, cols[0])


static func _p_grass_side(img: Image, cols: Array[Color], seed: int, has_base: bool) -> void:
	if not has_base:
		img.fill(cols[0].darkened(0.5))
	var n := _noise(seed, 0.25)
	for x in S:
		var depth := 4 + int(_h(x, 0, seed) * 3.0) + (2 if _h(x, 1, seed) < 0.25 else 0)
		for y in depth:
			img.set_pixel(x, y, _pal(cols, n[y * S + x] * 0.8 + 0.2 - y * 0.04))
		img.set_pixel(x, depth, img.get_pixel(x, depth).darkened(0.35))


static func _p_ore(img: Image, cols: Array[Color], seed: int, count: int, has_base: bool) -> void:
	if not has_base:
		img.fill(Color(0.2, 0.2, 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var cx := rng.randf_range(3.0, 29.0)
		var cy := rng.randf_range(3.0, 29.0)
		var r := rng.randf_range(2.0, 3.6)
		for y in range(int(cy - r - 2), int(cy + r + 2)):
			for x in range(int(cx - r - 2), int(cx + r + 2)):
				var px := posmod(x, S)
				var py := posmod(y, S)
				var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
				if d < r:
					var k := 1.0 - d / r
					if _h(px, py, seed + i) < 0.55 + k:
						img.set_pixel(px, py, cols[clampi(int(k * 3.0), 0, 2)])
				elif d < r + 0.9:
					img.set_pixel(px, py, img.get_pixel(px, py).darkened(0.25))
		img.set_pixel(posmod(int(cx) - 1, S), posmod(int(cy) - 1, S), cols[3])


static func _p_log_side(img: Image, cols: Array[Color], seed: int) -> void:
	var n := _noise(seed, 0.15)
	for y in S:
		for x in S:
			var t := 0.5 + 0.35 * sin((x + n[y * S + x] * 3.0) * TAU / 8.0) + (_h(x, y, seed) - 0.5) * 0.25
			var c := _pal(cols, t)
			if _h(x, y / 4, seed + 3) < 0.06:
				c = cols[0]
			img.set_pixel(x, y, c)


static func _p_log_top(img: Image, cols: Array[Color], seed: int) -> void:
	var n := _noise(seed, 0.2)
	for y in S:
		for x in S:
			var d := Vector2(x - 15.5, y - 15.5).length()
			var c: Color
			if d > 13.5:
				c = cols[0] if _h(x, y, seed) < 0.5 else cols[1].darkened(0.2)
			else:
				var ring := sin(d * 1.5 + n[y * S + x] * 2.5) * 0.5 + 0.5
				c = _pal(cols, 0.3 + ring * 0.69)
			img.set_pixel(x, y, c)


static func _p_leaves(img: Image, cols: Array[Color], seed: int, glow: Color) -> void:
	var n := _noise(seed, 0.22)
	var holes := _noise(seed + 77, 0.3, 2)
	for y in S:
		for x in S:
			var i := y * S + x
			if holes[i] < 0.26:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c := _pal(cols, n[i] + (_h(x, y, seed) - 0.5) * 0.2)
			if holes[i] < 0.32:
				c = c.darkened(0.3)
			if _h(x, y, seed + 4) < 0.03:
				c = glow
			img.set_pixel(x, y, c)


static func _p_crystal(img: Image, cols: Array[Color], seed: int) -> void:
	var pts := _rand_pts(6, seed)
	for y in S:
		for x in S:
			var v := _voronoi(x, y, pts)
			var facet := int(v.z) % 3
			var t := 0.15 + facet * 0.22 + (1.0 - y / float(S)) * 0.15
			var c := _pal(cols, t)
			var edge := v.y - v.x
			if edge < 0.9:
				c = cols[cols.size() - 1]
			elif edge < 2.0:
				c = cols[cols.size() - 2]
			img.set_pixel(x, y, c)


static func _p_ice(img: Image, cols: Array[Color], seed: int) -> void:
	var n := _noise(seed, 0.12, 2)
	for y in S:
		for x in S:
			var t := 0.25 + n[y * S + x] * 0.5
			var c := _pal(cols, t)
			var diag := posmod(x + y, S)
			if diag >= 20 and diag <= 22:
				c = cols[cols.size() - 1]
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in 3:
		var p := Vector2i(rng.randi_range(0, 31), rng.randi_range(0, 31))
		for s in 16:
			img.set_pixel(posmod(p.x, S), posmod(p.y, S), cols[0])
			p += Vector2i(rng.randi_range(-1, 1), rng.randi_range(0, 1) * 2 - 1)


static func _p_magma(img: Image, cols: Array[Color], seed: int) -> void:
	var pts := _rand_pts(7, seed)
	var n := _noise(seed, 0.2)
	for y in S:
		for x in S:
			var v := _voronoi(x, y, pts)
			var edge := v.y - v.x
			var c: Color
			if edge < 1.0:
				c = cols[4]
			elif edge < 2.2:
				c = cols[3]
			elif edge < 3.4:
				c = cols[2]
			else:
				c = cols[0] if n[y * S + x] < 0.55 else cols[1]
			img.set_pixel(x, y, c)


static func _p_brick(img: Image, cols: Array[Color], seed: int, mortar: Color) -> void:
	var n := _noise(seed, 0.3)
	for y in S:
		var row := y / 8
		var off := 8 if row % 2 == 1 else 0
		for x in S:
			var lx := posmod(x + off, 16)
			var ly := y % 8
			if ly == 7 or lx == 15:
				img.set_pixel(x, y, mortar)
				continue
			var bid := (posmod(x + off, S) / 16) + row * 4
			var t := 0.2 + _h(bid, row, seed) * 0.5 + n[y * S + x] * 0.3
			var c := _pal(cols, t)
			if ly == 0:
				c = c.lightened(0.12)
			elif ly == 6:
				c = c.darkened(0.18)
			if _h(x, y, seed + 2) < 0.04:
				c = c.darkened(0.3)
			img.set_pixel(x, y, c)


static func _p_glyph(img: Image, seed: int, glow: Color, frame: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var dim := glow
	dim.a = 1.0
	for k in 5:
		var a := Vector2i(8 + rng.randi_range(0, 2) * 8, 8 + rng.randi_range(0, 2) * 8)
		var b := Vector2i(8 + rng.randi_range(0, 2) * 8, 8 + rng.randi_range(0, 2) * 8)
		_line(img, a, b, glow, true)
	for k in 3:
		var p := Vector2i(8 + rng.randi_range(0, 2) * 8, 8 + rng.randi_range(0, 2) * 8)
		_rect(img, p.x - 1, p.y - 1, 3, 3, glow.lightened(0.5))
	if frame:
		for i in S:
			for w in 2:
				img.set_pixel(i, w, glow)
				img.set_pixel(i, S - 1 - w, glow)
				img.set_pixel(w, i, glow)
				img.set_pixel(S - 1 - w, i, glow)


static func _p_metal(img: Image, cols: Array[Color], seed: int, def: Dictionary) -> void:
	var n := _noise(seed, 0.18, 2)
	for y in S:
		for x in S:
			var t := 0.35 + n[y * S + x] * 0.3 + (_h(x, y, seed) - 0.5) * 0.08
			var c := _pal(cols, t)
			if def.get("grid", false) and (x % 8 == 0 or y % 8 == 0):
				c = cols[0]
			if x == 0 or y == 0:
				c = cols[cols.size() - 1]
			elif x == S - 1 or y == S - 1:
				c = cols[0].darkened(0.3)
			img.set_pixel(x, y, c)
	if def.has("stripe"):
		var sc := Color.html(def.stripe)
		for y in range(13, 19):
			for x in range(1, S - 1):
				img.set_pixel(x, y, sc if ((x + y) / 3) % 2 == 0 else sc.darkened(0.6))
	if def.has("hazard"):
		var hc := Color.html(def.hazard)
		for y in S:
			for x in S:
				if x < 4 or y < 4 or x > S - 5 or y > S - 5:
					img.set_pixel(x, y, hc if ((x + y) / 4) % 2 == 0 else Color(0.08, 0.08, 0.1))
	for p in [Vector2i(3, 3), Vector2i(28, 3), Vector2i(3, 28), Vector2i(28, 28)]:
		img.set_pixel(p.x, p.y, cols[cols.size() - 1].lightened(0.3))
		img.set_pixel(p.x + 1, p.y + 1, cols[0].darkened(0.4))


static func _p_machine(img: Image, cols: Array[Color], seed: int, def: Dictionary) -> void:
	_p_metal(img, cols, seed, {})
	var acc := Color.html(def.get("accent", "#4fe3ff"))
	var dark := Color(0.04, 0.05, 0.08)
	match def.get("deco", "panel"):
		"vent":
			for row in 5:
				var y := 7 + row * 4
				_rect(img, 6, y, 20, 2, dark)
				_rect(img, 6, y + 2, 20, 1, cols[3])
			_rect(img, 14, 27, 4, 2, acc)
		"panel":
			_rect(img, 6, 6, 20, 20, cols[1].darkened(0.15))
			_rect(img, 6, 6, 20, 1, cols[0])
			_rect(img, 6, 25, 20, 1, cols[3])
			_rect(img, 15, 15, 2, 2, acc)
		"screen":
			_rect(img, 5, 6, 22, 15, cols[0].darkened(0.5))
			_rect(img, 6, 7, 20, 13, Color(0.02, 0.05, 0.08))
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			for r in 5:
				var w := rng.randi_range(5, 17)
				_rect(img, 8, 9 + r * 2, w, 1, acc if r != 2 else acc.darkened(0.4))
			for b in 4:
				_rect(img, 7 + b * 5, 24, 3, 2, acc if b == 0 else cols[3])
		"furnace":
			_rect(img, 7, 9, 18, 16, dark)
			for y in range(10, 24):
				var heat := 1.0 - absf(y - 19.0) / 8.0
				for x in range(8, 24):
					if y % 3 != 0:
						img.set_pixel(x, y, acc.lerp(Color(1, 0.95, 0.6), clampf(heat, 0, 1) * 0.6).darkened(0.1 + _h(x, y, seed) * 0.25))
					else:
						img.set_pixel(x, y, cols[2])
		"ring":
			for y in S:
				for x in S:
					var d := Vector2(x - 15.5, y - 15.5).length()
					if d > 7.0 and d < 9.5:
						img.set_pixel(x, y, acc)
					elif d >= 9.5 and d < 10.5:
						img.set_pixel(x, y, dark)
					elif d < 3.0:
						img.set_pixel(x, y, acc.lightened(0.6))
					elif d <= 7.0:
						img.set_pixel(x, y, dark.lerp(acc, 0.25))
		"bars":
			_rect(img, 6, 6, 20, 20, dark)
			for b in 4:
				var h := 6 + int(_h(b, 0, seed) * 12.0)
				_rect(img, 8 + b * 4, 24 - h, 3, h, acc)
				_rect(img, 8 + b * 4, 24 - h, 3, 1, acc.lightened(0.5))
		"drill":
			for y in range(8, 26):
				var half := int((26 - y) * 0.45)
				for x in range(16 - half, 16 + half + 1):
					var c := acc if (x + y) % 4 < 2 else acc.darkened(0.35)
					img.set_pixel(x, y, c)
			_rect(img, 10, 5, 12, 3, cols[3])
		"cross":
			_rect(img, 13, 7, 6, 18, acc)
			_rect(img, 7, 13, 18, 6, acc)


static func _p_solar(img: Image, cols: Array[Color], seed: int) -> void:
	for y in S:
		for x in S:
			var lx := x % 8
			var ly := y % 8
			var c: Color
			if lx == 0 or ly == 0:
				c = Color(0.75, 0.78, 0.85)
			else:
				var t := 0.3 + (lx + ly) / 28.0 + (_h(x, y, seed) - 0.5) * 0.1
				c = _pal(cols, t)
				if lx == 1 and ly == 1:
					c = cols[3]
			img.set_pixel(x, y, c)


static func _p_cable(img: Image, cols: Array[Color], seed: int, acc: Color) -> void:
	_p_noise(img, cols, seed, 0.3, 0.0)
	_rect(img, 11, 0, 10, S, cols[2].lightened(0.1))
	_rect(img, 0, 11, S, 10, cols[2].lightened(0.1))
	_rect(img, 15, 0, 2, S, acc)
	_rect(img, 0, 15, S, 2, acc)
	_rect(img, 13, 13, 6, 6, acc.lightened(0.4))


static func _p_crate(img: Image, cols: Array[Color], seed: int, acc: Color) -> void:
	for y in S:
		for x in S:
			var c := _pal(cols, 0.3 + (0.2 if (x / 6) % 2 == 0 else 0.0) + (_h(x, y, seed) - 0.5) * 0.15)
			img.set_pixel(x, y, c)
	for i in S:
		for w in 3:
			img.set_pixel(i, w, cols[3])
			img.set_pixel(i, S - 1 - w, cols[3])
			img.set_pixel(w, i, cols[3])
			img.set_pixel(S - 1 - w, i, cols[3])
	_line(img, Vector2i(3, 3), Vector2i(28, 28), cols[3], false)
	_line(img, Vector2i(4, 3), Vector2i(28, 27), cols[3], false)
	_line(img, Vector2i(28, 3), Vector2i(3, 28), cols[3], false)
	_line(img, Vector2i(27, 3), Vector2i(3, 27), cols[3], false)
	_rect(img, 1, 1, 3, 3, acc)
	_rect(img, 28, 28, 3, 3, acc)


static func _p_hydro(img: Image, cols: Array[Color], seed: int) -> void:
	var soil: Array[Color] = [cols[0], cols[1], cols[2]]
	for y in S:
		for x in S:
			var c := _pal(soil, 0.2 + _h(x, y, seed) * 0.7)
			if y % 8 == 0:
				c = Color(0.55, 0.6, 0.68)
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for row in 4:
		for k in 4:
			var x := 3 + k * 8 + rng.randi_range(-1, 1)
			var y := 4 + row * 8
			img.set_pixel(x, y, cols[3])
			img.set_pixel(x - 1, y - 1, cols[4])
			img.set_pixel(x + 1, y - 1, cols[4])
			img.set_pixel(x, y + 1, cols[3])


static func _p_conveyor(img: Image, cols: Array[Color], seed: int, acc: Color) -> void:
	_p_noise(img, cols, seed, 0.3, 0.0)
	_rect(img, 0, 0, 3, S, Color(0.6, 0.62, 0.7))
	_rect(img, S - 3, 0, 3, S, Color(0.6, 0.62, 0.7))
	for k in 2:
		var by := 4 + k * 16
		for i in 8:
			img.set_pixel(8 + i, by + i, acc)
			img.set_pixel(23 - i, by + i, acc)
			img.set_pixel(8 + i, by + i + 1, acc.darkened(0.4))
			img.set_pixel(23 - i, by + i + 1, acc.darkened(0.4))


static func _p_soil(img: Image, cols: Array[Color], seed: int) -> void:
	_p_noise(img, cols, seed, 0.3, 0.05)
	for y in S:
		if y % 6 == 5:
			for x in S:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.35))


static func _p_hive(img: Image, cols: Array[Color], seed: int, acc: Color) -> void:
	var pts := _rand_pts(9, seed)
	for y in S:
		for x in S:
			var v := _voronoi(x, y, pts)
			var c: Color
			if v.y - v.x < 1.2:
				c = cols[0]
			elif v.x < 1.6:
				c = acc
			else:
				c = _pal(cols, 0.3 + v.x / 10.0)
			img.set_pixel(x, y, c)


static func _p_glass(img: Image, cols: Array[Color]) -> void:
	var tint := cols[0]
	for y in S:
		for x in S:
			var c := Color(tint.r, tint.g, tint.b, 0.0)
			if x < 2 or y < 2 or x > S - 3 or y > S - 3:
				c = Color(0.62, 0.68, 0.76, 1.0)
			else:
				var d := posmod(x - y, S)
				if d == 6 or d == 7 or d == 12:
					c = Color(1, 1, 1, 0.9)
				elif _h(x, y, 3) < 0.04:
					c = Color(tint.r, tint.g, tint.b, 0.8)
			img.set_pixel(x, y, c)


static func _p_lamp(img: Image, cols: Array[Color]) -> void:
	for y in S:
		for x in S:
			var c: Color
			if x < 3 or y < 3 or x > S - 4 or y > S - 4:
				c = cols[2]
			else:
				var d := Vector2(x - 15.5, y - 15.5).length() / 14.0
				c = cols[0].lerp(cols[1], clampf(d, 0, 1))
			img.set_pixel(x, y, c)


static func _p_water(img: Image, cols: Array[Color], seed: int) -> void:
	var n := _noise(seed, 0.15)
	for y in S:
		for x in S:
			var c := _pal(cols, n[y * S + x])
			c.a = 0.78
			img.set_pixel(x, y, c)


static func _p_plant(img: Image, cols: Array[Color], seed: int, shape: String) -> void:
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	match shape:
		"blades":
			for b in 11:
				var x0 := rng.randi_range(2, 29)
				var h := rng.randi_range(9, 26)
				var lean := rng.randf_range(-0.35, 0.35)
				for i in h:
					var t := i / float(h)
					var x := int(round(x0 + lean * i))
					var c := cols[0].lerp(cols[1], t * 1.4) if t < 0.7 else cols[2]
					_px(img, x, S - 1 - i, c)
					if i < h / 3:
						_px(img, x + 1, S - 1 - i, cols[0])
		"shroom":
			_mushroom(img, cols, 16, 31, 14, 7, 9)
			_mushroom(img, cols, 6, 31, 8, 4, 5)
			_mushroom(img, cols, 26, 31, 9, 4, 5)
		"flower":
			for k in 3:
				var x0 := 8 + k * 8 + rng.randi_range(-1, 1)
				var h := rng.randi_range(12, 22)
				for i in h:
					_px(img, x0, S - 1 - i, cols[0])
				var cy := S - 1 - h
				for py in range(-3, 4):
					for px in range(-3, 4):
						var d := Vector2(px, py).length()
						if d < 3.3:
							_px(img, x0 + px, cy + py, cols[1] if d > 1.2 else cols[2])
		"crystal":
			for k in 4:
				var x0 := rng.randi_range(5, 26)
				var h := rng.randi_range(10, 24)
				var w := rng.randi_range(2, 4)
				for i in h:
					var half := int(w * (1.0 - i / float(h)) + 0.5)
					for dx in range(-half, half + 1):
						var c := cols[1] if dx <= 0 else cols[0]
						if i > h - 3:
							c = cols[2]
						_px(img, x0 + dx, S - 1 - i, c)


static func _mushroom(img: Image, cols: Array[Color], cx: int, base: int, stem_h: int, rx: int, ry: int) -> void:
	for i in stem_h:
		_px(img, cx, base - i, cols[0])
		_px(img, cx - 1, base - i, cols[0].darkened(0.2))
	var cy := base - stem_h
	for py in range(-ry, 2):
		for px in range(-rx, rx + 1):
			var d := Vector2(px / float(rx), py / float(ry)).length()
			if d <= 1.0:
				var c := cols[2] if d < 0.75 else cols[1]
				if _h(px + cx, py + cy, 11) < 0.12:
					c = cols[3]
				_px(img, cx + px, cy + py, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < S and y < S:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color, halo: bool) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in steps + 1:
		var t := i / float(maxi(steps, 1))
		var p := Vector2(a).lerp(Vector2(b), t)
		var x := int(round(p.x))
		var y := int(round(p.y))
		if halo:
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S:
					img.set_pixel(q.x, q.y, img.get_pixel(q.x, q.y).lerp(c, 0.35))
		_px(img, x, y, c)


# ---------------------------------------------------------------- icons

static func make_cube_icon(top: Image, right: Image, left: Image) -> Image:
	var img := _blank()
	for py in S:
		for px in S:
			var dx := px + 0.5 - 16.0
			var c := Color(0, 0, 0, 0)
			# top rhombus: T(16,1) R(30,8) B(16,15) L(2,8)
			var dy := py + 0.5 - 1.0
			var u := (dx / 14.0 + dy / 7.0) * 0.5
			var v := (dy / 7.0 - dx / 14.0) * 0.5
			if u >= 0.0 and v >= 0.0 and u <= 1.0 and v <= 1.0:
				c = top.get_pixel(clampi(int(u * S), 0, S - 1), clampi(int(v * S), 0, S - 1))
			else:
				var lx := px + 0.5 - 2.0
				if lx >= 0.0 and px < 16:
					var a := lx / 14.0
					var b := (py + 0.5 - 8.0 - 7.0 * a) / 16.0
					if b >= 0.0 and b <= 1.0:
						c = left.get_pixel(clampi(int(a * S), 0, S - 1), clampi(int(b * S), 0, S - 1)).darkened(0.22)
				elif px >= 16:
					var a2 := (px + 0.5 - 16.0) / 14.0
					var b2 := (py + 0.5 - 15.0 + 7.0 * a2) / 16.0
					if a2 <= 1.0 and b2 >= 0.0 and b2 <= 1.0:
						c = right.get_pixel(clampi(int(a2 * S), 0, S - 1), clampi(int(b2 * S), 0, S - 1)).darkened(0.42)
			if c.a > 0.0:
				c.a = 1.0
			img.set_pixel(px, py, c)
	_outline(img)
	return img


static func make_icon(def: Dictionary, seed: int) -> Image:
	var cols := _cols(def.get("c", ["#888888", "#bbbbbb", "#ffffff"]))
	while cols.size() < 4:
		cols.append(cols[cols.size() - 1].lightened(0.3))
	var img := _blank()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	match def.get("shape", "chunk"):
		"chunk":
			var pts := PackedVector2Array([Vector2(6, 14), Vector2(12, 6), Vector2(22, 5), Vector2(27, 13), Vector2(25, 24), Vector2(15, 27), Vector2(6, 22)])
			_poly(img, pts, cols[1])
			_poly(img, PackedVector2Array([Vector2(12, 6), Vector2(22, 5), Vector2(19, 14), Vector2(11, 14)]), cols[2])
			_poly(img, PackedVector2Array([Vector2(19, 14), Vector2(27, 13), Vector2(25, 24), Vector2(17, 20)]), cols[0])
			_rect(img, 14, 8, 3, 2, cols[3])
		"ingot":
			_poly(img, PackedVector2Array([Vector2(4, 20), Vector2(10, 12), Vector2(28, 12), Vector2(22, 20)]), cols[2])
			_poly(img, PackedVector2Array([Vector2(4, 20), Vector2(22, 20), Vector2(22, 26), Vector2(4, 26)]), cols[1])
			_poly(img, PackedVector2Array([Vector2(22, 20), Vector2(28, 12), Vector2(28, 18), Vector2(22, 26)]), cols[0])
			_rect(img, 11, 14, 10, 1, cols[3])
		"rod":
			_rect(img, 13, 3, 6, 26, cols[1])
			_rect(img, 13, 3, 2, 26, cols[2])
			_rect(img, 11, 3, 10, 3, Color(0.6, 0.65, 0.72))
			_rect(img, 11, 26, 10, 3, Color(0.6, 0.65, 0.72))
			_rect(img, 15, 8, 2, 16, cols[3])
		"gem":
			_poly(img, PackedVector2Array([Vector2(16, 3), Vector2(27, 13), Vector2(16, 29), Vector2(5, 13)]), cols[1])
			_poly(img, PackedVector2Array([Vector2(16, 3), Vector2(27, 13), Vector2(16, 13)]), cols[2])
			_poly(img, PackedVector2Array([Vector2(5, 13), Vector2(16, 13), Vector2(16, 29)]), cols[0])
			_rect(img, 12, 9, 2, 2, cols[3])
		"dust":
			for k in 60:
				var a := rng.randf() * TAU
				var r := sqrt(rng.randf()) * 11.0
				_px(img, int(16 + cos(a) * r), int(20 + sin(a) * r * 0.55), cols[rng.randi_range(0, 3)])
		"blob", "seed", "fruit", "core", "coin":
			var r := 11.0 if def.shape != "seed" else 7.0
			for y in S:
				for x in S:
					var d := Vector2(x - 15.5, y - 16.5).length() / r
					if d <= 1.0:
						var hl := Vector2(x - 12.0, y - 12.0).length() / r
						var c := cols[0].lerp(cols[1], 1.0 - d)
						if hl < 0.35:
							c = cols[2]
						if def.shape == "core" and d < 0.4:
							c = cols[2].lerp(Color.WHITE, 0.6)
						if def.shape == "coin" and abs(d - 0.7) < 0.08:
							c = cols[0]
						img.set_pixel(x, y, c)
			if def.shape == "fruit":
				_rect(img, 15, 3, 2, 4, Color(0.2, 0.5, 0.2))
			if def.shape == "seed":
				for k in 3:
					_px(img, 9 + k * 7, 25, cols[1])
					_px(img, 9 + k * 7, 26, cols[0])
		"fiber", "petal":
			for k in 7:
				var x0 := 8 + k * 3
				for i in 22:
					var x := int(x0 + sin(i * 0.3 + k) * 2.0)
					_px(img, x, 27 - i, cols[k % 3])
		"shroom":
			_mushroom(img, cols, 16, 29, 10, 11, 9)
		"meat":
			_poly(img, PackedVector2Array([Vector2(5, 16), Vector2(12, 7), Vector2(24, 8), Vector2(28, 17), Vector2(20, 26), Vector2(9, 25)]), cols[1])
			_poly(img, PackedVector2Array([Vector2(9, 16), Vector2(14, 11), Vector2(21, 12), Vector2(23, 18), Vector2(16, 22)]), cols[0])
			_rect(img, 14, 13, 4, 2, cols[2])
		"ration":
			_rect(img, 6, 8, 20, 18, cols[0])
			_rect(img, 6, 8, 20, 4, cols[1])
			_rect(img, 10, 15, 12, 6, cols[2])
		"medkit":
			_rect(img, 5, 9, 22, 17, cols[1])
			_rect(img, 12, 5, 8, 4, cols[0])
			_rect(img, 14, 11, 4, 13, cols[2])
			_rect(img, 10, 15, 12, 4, cols[2])
		"canister":
			_rect(img, 9, 7, 14, 21, cols[0])
			_rect(img, 10, 8, 4, 19, cols[1])
			_rect(img, 12, 3, 8, 4, Color(0.6, 0.65, 0.72))
			_rect(img, 9, 16, 14, 3, cols[2])
		"chip":
			_rect(img, 6, 6, 20, 20, cols[1])
			_rect(img, 10, 10, 12, 12, cols[0])
			for k in 5:
				_rect(img, 7 + k * 4, 3, 2, 3, cols[2])
				_rect(img, 7 + k * 4, 26, 2, 3, cols[2])
			_rect(img, 13, 13, 6, 6, cols[3])
		"plate":
			_poly(img, PackedVector2Array([Vector2(3, 18), Vector2(13, 8), Vector2(29, 12), Vector2(19, 23)]), cols[1])
			_poly(img, PackedVector2Array([Vector2(3, 18), Vector2(19, 23), Vector2(19, 26), Vector2(3, 21)]), cols[0])
			_line(img, Vector2i(10, 14), Vector2i(22, 17), cols[2], false)
		"artifact":
			_poly(img, PackedVector2Array([Vector2(16, 2), Vector2(26, 12), Vector2(22, 29), Vector2(10, 29), Vector2(6, 12)]), cols[1])
			_poly(img, PackedVector2Array([Vector2(16, 6), Vector2(22, 12), Vector2(16, 24), Vector2(10, 12)]), cols[0])
			_rect(img, 14, 11, 4, 6, cols[2])
			_rect(img, 15, 12, 2, 2, cols[3])
		"drill":
			_rect(img, 4, 15, 14, 8, cols[0])
			_rect(img, 4, 15, 14, 2, cols[0].lightened(0.3))
			_rect(img, 7, 22, 5, 7, cols[0].darkened(0.3))
			_poly(img, PackedVector2Array([Vector2(18, 14), Vector2(29, 19), Vector2(18, 24)]), cols[1])
			_rect(img, 8, 17, 4, 2, cols[2])
		"gun", "rifle":
			var long: bool = def.shape == "rifle"
			_rect(img, 3, 12, 22 if long else 16, 7, cols[0])
			_rect(img, 3, 12, 22 if long else 16, 2, cols[0].lightened(0.3))
			_rect(img, 25 if long else 19, 14, 5, 3, cols[1])
			_rect(img, 7, 19, 5, 9, cols[0].darkened(0.3))
			_rect(img, 12, 15, 8 if long else 4, 2, cols[2])
		"blade":
			_poly(img, PackedVector2Array([Vector2(8, 22), Vector2(26, 3), Vector2(28, 5), Vector2(11, 25)]), cols[1])
			_line(img, Vector2i(10, 22), Vector2i(26, 5), cols[2], false)
			_rect(img, 4, 22, 8, 3, cols[0])
			_rect(img, 5, 25, 3, 5, cols[0].darkened(0.3))
		"module":
			_rect(img, 5, 5, 22, 22, Color(0.25, 0.28, 0.34))
			_rect(img, 7, 7, 18, 18, cols[0])
			_rect(img, 11, 11, 10, 10, cols[1])
			_rect(img, 14, 14, 4, 4, cols[2])
		"rover":
			_rect(img, 4, 12, 24, 9, cols[0])
			_rect(img, 10, 7, 12, 6, cols[2])
			for wx in [8, 16, 24]:
				for y in range(20, 28):
					for x in range(wx - 3, wx + 3):
						if Vector2(x - wx + 0.5, y - 23.5).length() < 3.6:
							_px(img, x, y, Color(0.12, 0.12, 0.15))
			_rect(img, 4, 14, 24, 2, cols[1])
		"drone":
			_rect(img, 10, 12, 12, 8, cols[0])
			_rect(img, 3, 9, 8, 2, cols[1])
			_rect(img, 21, 9, 8, 2, cols[1])
			_rect(img, 14, 14, 4, 4, cols[2])
			_rect(img, 13, 20, 6, 6, cols[1].darkened(0.3))
		"engine":
			_rect(img, 8, 4, 16, 16, cols[0])
			_poly(img, PackedVector2Array([Vector2(8, 20), Vector2(24, 20), Vector2(28, 29), Vector2(4, 29)]), cols[0].darkened(0.3))
			_rect(img, 10, 24, 12, 4, cols[1])
			_rect(img, 13, 8, 6, 8, cols[2])
		_:
			_rect(img, 8, 8, 16, 16, cols[1])
	_outline(img)
	return img


static func _poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	for y in S:
		for x in S:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, c)


static func _outline(img: Image) -> void:
	var src := img.duplicate()
	var ol := Color(0.03, 0.02, 0.06, 1.0)
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a > 0.1:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S and src.get_pixel(q.x, q.y).a > 0.1:
					img.set_pixel(x, y, ol)
					break

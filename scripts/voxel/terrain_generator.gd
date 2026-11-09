extends RefCounted
## Seed-based terrain generator for one planet. Created on the main thread, then
## generate_chunk() runs on worker threads. It only reads its own fields and noise objects.

const CS := 16
const H := 128
const GS := 4                 # density grid step (blocks)
const GY := H / GS + 1        # 33 vertical samples
const GXZ := CS / GS + 1      # 5 horizontal samples

var seed: int
var planet: Dictionary
var ptype: String
var sea: int
var fluid: int = 0
var freeze_sea := false
var biomes: Array = []
var ores: Array = []
var replaceable := {}
var crystal_block := 0
var crystal_tries := 0
var ruins_chance := 0.0
var cave_width := 0.1
var cavern_thr := 0.6

var n_cont := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var n_mount := FastNoiseLite.new()
var n_temp := FastNoiseLite.new()
var n_moist := FastNoiseLite.new()
var n_cave1 := FastNoiseLite.new()
var n_cave2 := FastNoiseLite.new()
var n_cavern := FastNoiseLite.new()

var B := {}   # block name -> id cache
var kinds := PackedByteArray()
const PLANT_KIND := 4


func _init(p: Dictionary, world_seed: int) -> void:
	kinds = Reg.kind
	planet = p
	seed = world_seed ^ hash(p.id)
	ptype = p.get("type", "terrain")
	sea = int(p.get("sea_level", 0))
	freeze_sea = p.get("freeze_sea", false)
	var fl: String = p.get("fluid", "none")
	fluid = Reg.block(fl) if fl != "none" else 0
	for name in Reg.block_ids.keys():
		B[name] = Reg.block_ids[name]
	var nz: Dictionary = p.get("noise", {})
	_setup(n_cont, 1, nz.get("freq", 0.004), 3, FastNoiseLite.FRACTAL_FBM)
	_setup(n_detail, 2, nz.get("detail", 0.02), 3, FastNoiseLite.FRACTAL_FBM)
	_setup(n_mount, 3, nz.get("freq", 0.004) * 2.2, 3, FastNoiseLite.FRACTAL_RIDGED)
	_setup(n_temp, 4, nz.get("biome_freq", 0.002), 2, FastNoiseLite.FRACTAL_FBM)
	_setup(n_moist, 5, nz.get("biome_freq", 0.002) * 1.3, 2, FastNoiseLite.FRACTAL_FBM)
	var cv: Dictionary = p.get("caves", {})
	_setup(n_cave1, 6, cv.get("freq", 0.03), 2, FastNoiseLite.FRACTAL_FBM)
	_setup(n_cave2, 7, cv.get("freq", 0.03), 2, FastNoiseLite.FRACTAL_FBM)
	_setup(n_cavern, 8, cv.get("freq", 0.03) * 0.6, 2, FastNoiseLite.FRACTAL_FBM)
	cave_width = cv.get("width", 0.1)
	cavern_thr = cv.get("cavern", 0.6)
	for b in p.get("biomes", []):
		var r: Dictionary = b.duplicate()
		r["surface_id"] = _id(b.surface)
		r["sub_id"] = _id(b.sub)
		r["stone_id"] = _id(b.stone)
		var fl_ids := []
		for f in b.get("flora", []):
			fl_ids.append(_id(f))
		r["flora_ids"] = fl_ids
		biomes.append(r)
		replaceable[r.stone_id] = true
		replaceable[r.sub_id] = true
	for o in p.get("ores", []):
		var r: Dictionary = o.duplicate()
		r["id"] = _id(o.block)
		ores.append(r)
	var cr: Dictionary = p.get("crystals", {})
	crystal_block = _id(cr.get("block", "lumen_crystal"))
	crystal_tries = int(cr.get("tries", 0))
	ruins_chance = float(p.get("ruins", 0.0))


func _setup(n: FastNoiseLite, salt: int, freq: float, oct: int, frac: int) -> void:
	n.seed = seed + salt * 1013
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = frac
	n.fractal_octaves = oct


func _id(name: String) -> int:
	return B.get(name, 0)


static func idx(x: int, y: int, z: int) -> int:
	return y + H * (x + CS * z)


# ------------------------------------------------------------- columns

## Returns [height, biome_index, blended_amp] for a world column.
func column(wx: int, wz: int) -> Array:
	var t := n_temp.get_noise_2d(wx, wz) * 1.6
	var m := n_moist.get_noise_2d(wx, wz) * 1.6
	var wsum := 0.0
	var base_b := 0.0
	var amp_b := 0.0
	var best := 0
	var best_w := -1.0
	for i in biomes.size():
		var b: Dictionary = biomes[i]
		var dt: float = t - b.t
		var dm: float = m - b.m
		var d2 := dt * dt + dm * dm
		var w := 1.0 / (d2 * d2 + 0.0004)
		wsum += w
		base_b += w * float(b.base)
		amp_b += w * float(b.amp)
		if w > best_w:
			best_w = w
			best = i
	base_b /= wsum
	amp_b /= wsum
	var nz: Dictionary = planet.get("noise", {})
	var cont := n_cont.get_noise_2d(wx, wz)
	var det := n_detail.get_noise_2d(wx, wz)
	var ridge := 1.0 - absf(n_mount.get_noise_2d(wx, wz))
	ridge = ridge * ridge * ridge
	var h := float(nz.get("base", 40)) + base_b + cont * 12.0 * amp_b + det * 5.0 * amp_b
	h += ridge * float(nz.get("mountain", 20)) * amp_b * smoothstep(-0.2, 0.5, cont)
	var bdef: Dictionary = biomes[best]
	if bdef.has("terrace"):
		var tr: float = bdef.terrace
		h = floor(h / tr) * tr + clampf((h - floor(h / tr) * tr) - tr * 0.6, 0.0, tr)
	return [clampi(int(h), 4, H - 24), best, amp_b]


func surface_height(wx: int, wz: int) -> int:
	return column(wx, wz)[0]


# ------------------------------------------------------------- chunk

func generate_chunk(cx: int, cz: int, mods: Dictionary) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(CS * CS * H)
	var ox := cx * CS
	var oz := cz * CS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cx, cz, seed))
	var heights := PackedInt32Array()
	heights.resize(CS * CS)
	var bidx := PackedInt32Array()
	bidx.resize(CS * CS)
	if ptype == "terrain":
		_gen_terrain(b, ox, oz, heights, bidx)
	else:
		_gen_floating(b, ox, oz, heights, bidx)
	_gen_ores(b, rng, heights)
	_gen_crystals(b, rng, heights)
	_gen_surface(b, ox, oz, rng, heights, bidx)
	if ruins_chance > 0.0 and rng.randf() < ruins_chance:
		_gen_ruin(b, rng, heights)
	for i in mods:
		b[i] = mods[i]
	return b


func _column_grid(ox: int, oz: int, noise: FastNoiseLite, yscale: float) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(GXZ * GXZ * GY)
	for iz in GXZ:
		for ix in GXZ:
			var wx := ox + ix * GS
			var wz := oz + iz * GS
			for iy in GY:
				g[iy + GY * (ix + GXZ * iz)] = noise.get_noise_3d(wx, iy * GS * yscale, wz)
	return g


static func _col_interp(g: PackedFloat32Array, x: int, z: int) -> PackedFloat32Array:
	var fx := x / float(GS)
	var fz := z / float(GS)
	var ix := mini(int(fx), GXZ - 2)
	var iz := mini(int(fz), GXZ - 2)
	var tx := fx - ix
	var tz := fz - iz
	var out := PackedFloat32Array()
	out.resize(GY)
	var a0 := GY * (ix + GXZ * iz)
	var a1 := GY * (ix + 1 + GXZ * iz)
	var a2 := GY * (ix + GXZ * (iz + 1))
	var a3 := GY * (ix + 1 + GXZ * (iz + 1))
	for iy in GY:
		var v0 := lerpf(g[a0 + iy], g[a1 + iy], tx)
		var v1 := lerpf(g[a2 + iy], g[a3 + iy], tx)
		out[iy] = lerpf(v0, v1, tz)
	return out


static func _sample_y(col: PackedFloat32Array, y: int) -> float:
	var fy := y / float(GS)
	var iy := mini(int(fy), GY - 2)
	return lerpf(col[iy], col[iy + 1], fy - iy)


func _gen_terrain(b: PackedByteArray, ox: int, oz: int, heights: PackedInt32Array, bidx: PackedInt32Array) -> void:
	var g1 := _column_grid(ox, oz, n_cave1, 1.6)
	var g2 := _column_grid(ox, oz, n_cave2, 1.6)
	var g3 := _column_grid(ox, oz, n_cavern, 1.3)
	var bedrock: int = B.bedrock
	var ice: int = B.ice
	for z in CS:
		for x in CS:
			var col := column(ox + x, oz + z)
			var h: int = col[0]
			var bi: int = col[1]
			var bio: Dictionary = biomes[bi]
			heights[x + CS * z] = h
			bidx[x + CS * z] = bi
			var c1 := _col_interp(g1, x, z)
			var c2 := _col_interp(g2, x, z)
			var c3 := _col_interp(g3, x, z)
			var surface: int = bio.surface_id
			var sub: int = bio.sub_id
			var stone: int = bio.stone_id
			var underwater := fluid != 0 and h < sea
			if underwater:
				surface = sub
			var base := H * (x + CS * z)
			for y in range(0, h + 1):
				var id: int
				if y == 0 or (y == 1 and ((x * 7 + z * 13) & 3) == 0):
					id = bedrock
				elif y == h:
					id = surface
				elif y > h - 4:
					id = sub
				else:
					id = stone
				if y > 1 and id != bedrock:
					var worm := absf(_sample_y(c1, y)) < cave_width and absf(_sample_y(c2, y)) < cave_width
					var cav := y < h - 8 and _sample_y(c3, y) > cavern_thr
					if (worm and (y < h - 1 or not underwater)) or cav:
						id = fluid if (fluid == B.get("magma", -1) and y < 12) else 0
				b[base + y] = id
			if fluid != 0:
				for y in range(h + 1, sea + 1):
					if b[base + y] == 0:
						b[base + y] = ice if (freeze_sea and y == sea) else fluid
			# real top for decoration
			var top := h
			while top > 0 and b[base + top] == 0:
				top -= 1
			heights[x + CS * z] = top if b[base + top] == surface else -1


func _gen_floating(b: PackedByteArray, ox: int, oz: int, heights: PackedInt32Array, bidx: PackedInt32Array) -> void:
	var asteroids := ptype == "asteroids"
	var g1 := _column_grid(ox, oz, n_detail, 1.0)
	var g2 := _column_grid(ox, oz, n_cont, 1.0)
	var bio: Dictionary = biomes[0]
	var center := float(planet.get("noise", {}).get("base", 64))
	var spread := 46.0 if asteroids else 34.0
	for z in CS:
		for x in CS:
			var c1 := _col_interp(g1, x, z)
			var c2 := _col_interp(g2, x, z)
			var base := H * (x + CS * z)
			bidx[x + CS * z] = 0
			heights[x + CS * z] = -1
			var above_air := true
			var depth := 0
			for y in range(H - 2, 1, -1):
				var fall := 1.0 - absf(y - center) / spread
				var d := _sample_y(c1, y) * 0.9 + _sample_y(c2, y) * 0.6 + fall * 0.55 - (0.62 if asteroids else 0.32)
				if d > 0.0:
					var id: int
					if above_air:
						id = bio.surface_id
						if heights[x + CS * z] < 0:
							heights[x + CS * z] = y
						depth = 0
					elif depth < 3:
						id = bio.sub_id
					else:
						id = bio.stone_id
					b[base + y] = id
					depth += 1
					above_air = false
				else:
					above_air = true
			if heights[x + CS * z] >= H - 4:
				heights[x + CS * z] = -1


func _gen_ores(b: PackedByteArray, rng: RandomNumberGenerator, heights: PackedInt32Array) -> void:
	for o in ores:
		var id: int = o.id
		for v in int(o.veins):
			var p := Vector3i(rng.randi_range(1, 14), rng.randi_range(int(o.min), int(o.max)), rng.randi_range(1, 14))
			for s in int(o.size):
				if p.x >= 0 and p.x < CS and p.z >= 0 and p.z < CS and p.y > 0 and p.y < H:
					var i := idx(p.x, p.y, p.z)
					if replaceable.has(b[i]):
						b[i] = id
				p += Vector3i(rng.randi_range(-1, 1), rng.randi_range(-1, 1), rng.randi_range(-1, 1))


func _gen_crystals(b: PackedByteArray, rng: RandomNumberGenerator, heights: PackedInt32Array) -> void:
	if crystal_block == 0:
		return
	var bud: int = B.get("crystalbud", 0)
	for t in crystal_tries:
		var x := rng.randi_range(1, 14)
		var z := rng.randi_range(1, 14)
		var y := rng.randi_range(4, 70)
		var i := idx(x, y, z)
		if b[i] != 0 or not replaceable.has(b[i - 1]):
			continue
		var tall := rng.randi_range(1, 3)
		for k in tall:
			if y + k < H and b[i + k] == 0:
				b[i + k] = crystal_block
		for o in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var j := idx(x + o.x, y, z + o.z)
			if b[j] == 0 and replaceable.has(b[j - 1]) and rng.randf() < 0.5:
				b[j] = bud if rng.randf() < 0.6 else crystal_block


func _gen_surface(b: PackedByteArray, ox: int, oz: int, rng: RandomNumberGenerator, heights: PackedInt32Array, bidx: PackedInt32Array) -> void:
	for z in CS:
		for x in CS:
			var h := heights[x + CS * z]
			if h < 1 or h > H - 14:
				continue
			var bio: Dictionary = biomes[bidx[x + CS * z]]
			var i := idx(x, h + 1, z)
			if b[i] != 0:
				continue
			var r := rng.randf()
			var tree: String = bio.get("tree", "")
			if tree != "" and x >= 3 and x <= 12 and z >= 3 and z <= 12 and r < float(bio.trees):
				_tree(b, tree, x, h + 1, z, rng)
			elif r < float(bio.trees) + float(bio.flora_density) and bio.flora_ids.size() > 0:
				b[i] = bio.flora_ids[rng.randi() % bio.flora_ids.size()]


func _put(b: PackedByteArray, x: int, y: int, z: int, id: int, only_air := true) -> void:
	if x < 0 or z < 0 or x >= CS or z >= CS or y <= 0 or y >= H:
		return
	var i := idx(x, y, z)
	if only_air and b[i] != 0 and kinds[b[i]] != PLANT_KIND:
		return
	b[i] = id


func _tree(b: PackedByteArray, kind: String, x: int, y: int, z: int, rng: RandomNumberGenerator) -> void:
	match kind:
		"glowtree":
			var h := rng.randi_range(5, 8)
			for k in h:
				_put(b, x, y + k, z, B.glowwood)
			var top := y + h
			var r := rng.randi_range(2, 3)
			for dy in range(-2, r):
				for dz in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var d := dx * dx + dz * dz + dy * dy * 2
						if d <= r * r + 1 and rng.randf() > 0.12:
							_put(b, x + dx, top + dy, z + dz, B.glowleaf)
			for k in 4:
				var hx := x + rng.randi_range(-r, r)
				var hz := z + rng.randi_range(-r, r)
				for d in rng.randi_range(1, 3):
					_put(b, hx, top - 3 - d, hz, B.glowleaf)
		"spire":
			var h := rng.randi_range(3, 7)
			for k in h:
				_put(b, x, y + k, z, B.spire)
			if h > 4:
				var dir: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
				_put(b, x + dir.x, y + 2, z + dir.y, B.spire)
				_put(b, x + dir.x, y + 3, z + dir.y, B.spire)
		"frosttree":
			var h := rng.randi_range(6, 10)
			for k in h:
				_put(b, x, y + k, z, B.frostwood)
			for layer in range(2, h + 1):
				var r := int((h - layer) * 0.4) + 1
				if layer % 2 == 1 and layer != h:
					continue
				for dz in range(-r, r + 1):
					for dx in range(-r, r + 1):
						if absi(dx) + absi(dz) <= r:
							_put(b, x + dx, y + layer, z + dz, B.frostleaf)
			_put(b, x, y + h, z, B.frostleaf)
		"crystal_spike":
			var h := rng.randi_range(2, 5)
			for k in h:
				_put(b, x, y + k, z, B.lumen_crystal)
			_put(b, x + 1, y, z, B.lumen_crystal)
		"ice_spike":
			var h := rng.randi_range(4, 11)
			for k in h:
				_put(b, x, y + k, z, B.ice)
				if k < h / 3:
					for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						_put(b, x + o.x, y + k, z + o.y, B.ice)
		"ember_spike":
			var h := rng.randi_range(3, 6)
			for k in h:
				_put(b, x, y + k, z, B.volcanic)
			_put(b, x, y + h, z, B.ember_crystal)


func _gen_ruin(b: PackedByteArray, rng: RandomNumberGenerator, heights: PackedInt32Array) -> void:
	var cx := 8
	var cz := 8
	var gy := heights[cx + CS * cz]
	if gy < 2 or gy > H - 16:
		return
	var brick: int = B.ruin_brick
	var glyph: int = B.ruin_glyph
	var r := rng.randi_range(3, 5)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var z := cz + dz
			# foundation down to ground
			for y in range(gy - 3, gy + 1):
				_put(b, x, y, z, brick, false)
			for y in range(gy + 1, gy + 7):
				_put(b, x, y, z, 0, false)
			var edge := absi(dx) == r or absi(dz) == r
			if edge:
				var wall_h := rng.randi_range(1, 5)
				for y in range(gy + 1, gy + 1 + wall_h):
					var id := glyph if (y == gy + 2 and rng.randf() < 0.2) else brick
					_put(b, x, y, z, id, false)
	for c in [Vector2i(-r, -r), Vector2i(r, -r), Vector2i(-r, r), Vector2i(r, r)]:
		var ph := rng.randi_range(4, 7)
		for y in range(gy + 1, gy + ph):
			_put(b, cx + c.x, y, cz + c.y, brick, false)
		_put(b, cx + c.x, gy + ph, cz + c.y, glyph, false)
	_put(b, cx, gy + 1, cz, B.ruin_cache, false)
	_put(b, cx, gy, cz, glyph, false)

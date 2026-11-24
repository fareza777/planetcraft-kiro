extends RefCounted
## Greedy voxel mesher. Pure functions over packed arrays so it can run on worker threads.
## Input: an 18 x 18 x H padded copy of a chunk column (1-block border from neighbours).
## Output per 16^3 section: up to three surfaces (opaque, cutout, fluid) plus lamp positions.

const CS := 16
const H := 128
const P := 18
const SX := H            # index stride for +x in padded array
const SY := 1            # index stride for +y
const SZ := H * P        # index stride for +z

const K_AIR := 0
const K_OPAQUE := 1
const K_CUTOUT := 2
const K_FLUID := 3
const K_PLANT := 4

const LAYER_OPAQUE := 0
const LAYER_CUTOUT := 1
const LAYER_FLUID := 2


class Buf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func arrays() -> Array:
		if v.is_empty():
			return []
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_COLOR] = c
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
		a[Mesh.ARRAY_INDEX] = idx
		return a


## Builds the padded volume. `cols` holds 9 PackedByteArrays ordered (dx+1) + 3*(dz+1).
static func pad(cols: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for pz in P:
		var sz := pz - 1
		var oz := 0 if sz < 0 else (2 if sz > 15 else 1)
		var lz := posmod(sz, CS)
		for px in P:
			var sx := px - 1
			var ox := 0 if sx < 0 else (2 if sx > 15 else 1)
			var lx := posmod(sx, CS)
			var src: PackedByteArray = cols[ox + 3 * oz]
			var s := H * (lx + CS * lz)
			out.append_array(src.slice(s, s + H))
	return out


## Highest opaque/cutout y per padded column (-1 if none).
static func tops(pd: PackedByteArray, kinds: PackedByteArray) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(P * P)
	for c in P * P:
		var base := c * H
		var y := H - 1
		while y >= 0:
			if kinds[pd[base + y]] == K_OPAQUE:
				break
			y -= 1
		t[c] = y
	return t


## Highest cutout (leaves, glass, crystals) y per padded column.
static func canopy(pd: PackedByteArray, kinds: PackedByteArray) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(P * P)
	for c in P * P:
		var base := c * H
		var y := H - 1
		while y >= 0:
			if kinds[pd[base + y]] == K_CUTOUT:
				break
			y -= 1
		t[c] = y
	return t


## Block-light level (0..15) emitted by each block id: lamps use their radius, other emissive
## blocks (crystals, magma, glowshrooms, glyphs) give a soft glow.
static func light_levels(kinds: PackedByteArray, emis: PackedByteArray, lightr: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for id in range(1, 256):
		if lightr[id] > 0.0:
			out[id] = clampi(int(lightr[id]) + 3, 1, 15)
		elif emis[id] == 1:
			if kinds[id] == K_FLUID:
				out[id] = 8
			elif kinds[id] == K_PLANT:
				out[id] = 4
			else:
				out[id] = 6
	return out


## Flood-fill light over the padded volume. Returns [sky, block] byte arrays (0..15) indexed
## like `pd`. Sky light falls straight down from the open sky and then spreads sideways one
## level per block, so overhangs, cave mouths and tunnels get a gradient instead of a cliff.
## Block light spreads from lamps and emissive blocks inside the pad plus `ext` lamps
## (Vector4 padded-local position + level) from neighbouring columns.
static func flood_light(pd: PackedByteArray, kinds: PackedByteArray, levels: PackedByteArray, ylo: int, ext: Array) -> Array:
	var n := P * P * H
	var sky := PackedByteArray()
	sky.resize(n)
	var blk := PackedByteArray()
	blk.resize(n)
	var q := PackedInt32Array()
	# Sky columns
	var colv := PackedInt32Array()
	colv.resize(P * P)
	for c in P * P:
		var base := c * H
		var v := 15
		var y := H - 1
		while y >= 0:
			var k := kinds[pd[base + y]]
			if k == K_OPAQUE:
				break
			if k == K_CUTOUT:
				v = maxi(v - 2, 0)
			elif k == K_FLUID:
				v = maxi(v - 1, 0)
			sky[base + y] = v
			y -= 1
		colv[c] = y   # highest opaque (or -1)
	# Seeds: lit cells that sit next to a darker neighbouring column.
	for pz in P:
		for px in P:
			var c := px + P * pz
			var hi := colv[c]
			if px > 0: hi = maxi(hi, colv[c - 1])
			if px < P - 1: hi = maxi(hi, colv[c + 1])
			if pz > 0: hi = maxi(hi, colv[c - P])
			if pz < P - 1: hi = maxi(hi, colv[c + P])
			var y0 := maxi(colv[c] + 1, ylo)
			for y in range(y0, mini(hi + 2, H)):
				if sky[c * H + y] > 1:
					q.append(c * H + y)
	_spread(q, sky, pd, kinds, ylo)
	# Block light seeds
	q = PackedInt32Array()
	for c in P * P:
		var base := c * H
		for y in range(ylo, H):
			var id := pd[base + y]
			if id == 0:
				continue
			var lv := levels[id]
			if lv == 0:
				continue
			if kinds[id] == K_FLUID and y + 1 < H and pd[base + y + 1] == id:
				continue
			if lv > blk[base + y]:
				blk[base + y] = lv
				q.append(base + y)
	for e in ext:
		var l: Vector4 = e
		var cx := clampi(int(l.x), 0, P - 1)
		var cz := clampi(int(l.z), 0, P - 1)
		var cy := clampi(int(l.y), ylo, H - 1)
		var d := absi(int(l.x) - cx) + absi(int(l.z) - cz) + absi(int(l.y) - cy)
		var lv := int(l.w) - d
		if lv <= 1:
			continue
		var i := cy + H * (cx + P * cz)
		if kinds[pd[i]] != K_OPAQUE and lv > blk[i]:
			blk[i] = lv
			q.append(i)
	_spread(q, blk, pd, kinds, ylo)
	return [sky, blk]


static func _spread(q: PackedInt32Array, L: PackedByteArray, pd: PackedByteArray, kinds: PackedByteArray, ylo: int) -> void:
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var v := L[i]
		if v <= 1:
			continue
		var y := i % H
		var c := i / H
		var px := c % P
		var pz := c / P
		for dir in 6:
			var ni := i
			match dir:
				0:
					if px == P - 1: continue
					ni = i + SX
				1:
					if px == 0: continue
					ni = i - SX
				2:
					if y == H - 1: continue
					ni = i + 1
				3:
					if y <= ylo: continue
					ni = i - 1
				4:
					if pz == P - 1: continue
					ni = i + SZ
				5:
					if pz == 0: continue
					ni = i - SZ
			var k := kinds[pd[ni]]
			if k == K_OPAQUE:
				continue
			var nv := v - (2 if k == K_CUTOUT else 1)
			if nv > L[ni]:
				L[ni] = nv
				if nv > 1:
					q.append(ni)


static func mesh_sections(pd: PackedByteArray, sections: PackedInt32Array, kinds: PackedByteArray, tiles: PackedInt32Array, emis: PackedByteArray, lightr: PackedFloat32Array, ext: Array = [], shapes: PackedByteArray = PackedByteArray()) -> Array:
	var occ := PackedByteArray()
	occ.resize(256)
	for i in 256:
		occ[i] = 1 if (kinds[i] == K_OPAQUE or kinds[i] == K_CUTOUT) else 0
	var smin := 99
	for s in sections:
		smin = mini(smin, s)
	var ylo := maxi(0, smin * CS - 16)
	var fl := flood_light(pd, kinds, light_levels(kinds, emis, lightr), ylo, ext)
	var results := []
	for s in sections:
		results.append(_mesh_section(pd, s, kinds, tiles, emis, lightr, occ, fl[0], fl[1], shapes))
	return results


static func _mesh_section(pd: PackedByteArray, s: int, kinds: PackedByteArray, tiles: PackedInt32Array, emis: PackedByteArray, lightr: PackedFloat32Array, occ: PackedByteArray, sky: PackedByteArray, blk: PackedByteArray, shapes: PackedByteArray = PackedByteArray()) -> Dictionary:
	var y0 := s * CS
	var bufs := [Buf.new(), Buf.new(), Buf.new()]
	var lights := []
	var strides := PackedInt32Array([SX, SY, SZ])
	var mask := PackedInt32Array()
	mask.resize(CS * CS)
	# Plants, lamps and a quick emptiness check.
	var any := false
	for z in CS:
		for x in CS:
			var base := y0 + H * ((x + 1) + P * (z + 1))
			for y in CS:
				var id := pd[base + y]
				if id == 0:
					continue
				any = true
				var k := kinds[id]
				if k == K_PLANT:
					_plant(bufs[LAYER_CUTOUT], x, y, z, tiles[id * 6], emis[id], float(maxi(sky[base + y], 1)) / 15.0, float(blk[base + y]) / 15.0)
				elif shapes.size() > id and shapes[id] > 0:
					var ls := float(maxi(sky[base + y], 1)) / 15.0
					var lb := float(blk[base + y]) / 15.0
					_shaped_block(bufs[LAYER_OPAQUE], x, y, z, tiles[id * 6], shapes[id], emis[id], ls, lb)
				if lightr[id] > 0.0:
					lights.append(Vector4(x + 0.5, y0 + y + 0.5, z + 0.5, lightr[id]))
	if not any:
		return {"s": s, "layers": [[], [], []], "lights": lights}
	for d in 3:
		var u := (d + 1) % 3
		var v := (d + 2) % 3
		var sd := strides[d]
		var su := strides[u]
		var sv := strides[v]
		for sgn in [1, -1]:
			var face := d * 2 + (0 if sgn > 0 else 1)
			for i in CS:
				# base index of slice cell (pos[d]=i, pos[u]=0, pos[v]=0)
				var p := [0, 0, 0]
				p[d] = i
				var base: int = (y0 + p[1]) + H * ((p[0] + 1) + P * (p[2] + 1))
				var ny: int = y0 + p[1] + (sgn if d == 1 else 0)
				var y_slice: int = y0 + p[1]
				var any_face := false
				for b in CS:
					for a in CS:
						var ci: int = base + a * su + b * sv
						var id := pd[ci]
						var key := 0
						if id != 0:
							var k := kinds[id]
							if k != K_PLANT and not (shapes.size() > id and shapes[id] > 0):
								var ni: int = ci + sgn * sd
								var nid: int
								if d == 1 and ny < 0:
									nid = 1
								elif d == 1 and ny >= H:
									nid = 0
								else:
									nid = pd[ni]
								var nk := kinds[nid]
								var vis := false
								var layer := LAYER_OPAQUE
								if k == K_OPAQUE:
									vis = nk != K_OPAQUE
								elif k == K_CUTOUT:
									vis = nk != K_OPAQUE and nid != id
									layer = LAYER_CUTOUT
								elif k == K_FLUID:
									vis = (nk == K_AIR or nk == K_PLANT or nk == K_CUTOUT) and nid != id
									layer = LAYER_FLUID
								if vis:
									var skyp := 0xFFFF
									var blkp := 0
									var sw := 0
									var ao := 0xFF
									if not (d == 1 and (ny < 0 or ny >= H)):
										var ls := maxi(sky[ni], 1)
										var lb := blk[ni]
										if layer != LAYER_FLUID:
											var um := occ[pd[ni - su]]
											var up := occ[pd[ni + su]]
											var vm := occ[pd[ni - sv]]
											var vp := occ[pd[ni + sv]]
											var a0 := _ao(um, vm, occ[pd[ni - su - sv]])
											var a1 := _ao(up, vm, occ[pd[ni + su - sv]])
											var a2 := _ao(up, vp, occ[pd[ni + su + sv]])
											var a3 := _ao(um, vp, occ[pd[ni - su + sv]])
											ao = a0 | (a1 << 2) | (a2 << 4) | (a3 << 6)
											# smooth light: average the open cells around each corner
											skyp = 0
											blkp = 0
											var corners := [[-su, -sv, um, vm], [su, -sv, up, vm], [su, sv, up, vp], [-su, sv, um, vp]]
											for kc in 4:
												var cc: Array = corners[kc]
												var ss := ls
												var sb := lb
												var cnt := 1
												var o1: int = ni + cc[0]
												var o2: int = ni + cc[1]
												if cc[2] == 0:
													ss += maxi(sky[o1], 1)
													sb += blk[o1]
													cnt += 1
												if cc[3] == 0:
													ss += maxi(sky[o2], 1)
													sb += blk[o2]
													cnt += 1
												if (cc[2] == 0 or cc[3] == 0) and occ[pd[o1 + cc[1]]] == 0:
													ss += maxi(sky[o1 + cc[1]], 1)
													sb += blk[o1 + cc[1]]
													cnt += 1
												skyp |= mini(15, (ss + cnt / 2) / cnt) << (kc * 4)
												blkp |= mini(15, (sb + cnt / 2) / cnt) << (kc * 4)
										else:
											# fluids: flat light; per-corner water depth (0 at the shore) for
											# shallow tint and foam. Packed into the unused AO bits + skyp.
											var dc := [8, 8, 8, 8]
											if d == 1 and sgn > 0:
												var corners := [[-su, -sv], [su, -sv], [su, sv], [-su, sv]]
												var d0 := _fluid_depth(pd, kinds, ci)
												for kc in 4:
													var cc: Array = corners[kc]
													var tot := d0 + _fluid_depth(pd, kinds, ci + cc[0]) + _fluid_depth(pd, kinds, ci + cc[1]) + _fluid_depth(pd, kinds, ci + cc[0] + cc[1])
													dc[kc] = mini(15, (tot + 2) / 4)
											ao = dc[0] | (dc[1] << 4)
											skyp = ls | (dc[2] << 4) | (dc[3] << 8)
											blkp = lb
									if layer == LAYER_CUTOUT and emis[id] == 0 and lightr[id] < 0.0:
										sw = 1
									key = (tiles[id * 6 + face] + 1) | (ao << 8) | (emis[id] << 16) | (layer << 17) | (sw << 19) | (skyp << 20) | (blkp << 36)
									any_face = true
						mask[a + CS * b] = key
				if not any_face:
					continue
				# Greedy merge
				for b in CS:
					var a := 0
					while a < CS:
						var key: int = mask[a + CS * b]
						if key == 0:
							a += 1
							continue
						var w := 1
						while a + w < CS and mask[a + w + CS * b] == key:
							w += 1
						var h := 1
						var done := false
						while b + h < CS and not done:
							for t in w:
								if mask[a + t + CS * (b + h)] != key:
									done = true
									break
							if not done:
								h += 1
						for hh in h:
							for t in w:
								mask[a + t + CS * (b + hh)] = 0
						_quad(bufs[(key >> 17) & 3], d, u, v, sgn, i, a, b, w, h, key)
						a += w
	return {"s": s, "layers": [bufs[0].arrays(), bufs[1].arrays(), bufs[2].arrays()], "lights": lights}


static func _fluid_depth(pd: PackedByteArray, kinds: PackedByteArray, i: int) -> int:
	var n := 0
	var y := i % H
	while n < 8 and y - n >= 0 and kinds[pd[i - n]] == K_FLUID:
		n += 1
	return n


static func _ao(s1: int, s2: int, c: int) -> int:
	if s1 == 1 and s2 == 1:
		return 0
	return 3 - (s1 + s2 + c)


static func _quad(buf: Buf, d: int, u: int, v: int, sgn: int, i: int, a: int, b: int, w: int, h: int, key: int) -> void:
	var tile := float((key & 0xFF) - 1)
	var ao := (key >> 8) & 0xFF
	var em := float((key >> 16) & 1)
	var layer := (key >> 17) & 3
	var skyp := (key >> 20) & 0xFFFF
	var blkp := (key >> 36) & 0xFFFF
	var plane := float(i + (1 if sgn > 0 else 0))
	if layer == LAYER_FLUID and d == 1 and sgn > 0:
		plane -= 0.12
	var cu := [a, a + w, a + w, a]
	var cv := [b, b, b + h, b + h]
	var normal := Vector3.ZERO
	normal[d] = sgn
	var start := buf.v.size()
	var aos := [ao & 3, (ao >> 2) & 3, (ao >> 4) & 3, (ao >> 6) & 3]
	for k in 4:
		var p := Vector3.ZERO
		p[d] = plane
		p[u] = cu[k]
		p[v] = cv[k]
		buf.v.append(p)
		buf.n.append(normal)
		var aof: float = [0.42, 0.62, 0.82, 1.0][aos[k]]
		if layer == LAYER_FLUID:
			var dep: int = [ao & 15, (ao >> 4) & 15, (skyp >> 4) & 15, (skyp >> 8) & 15][k]
			buf.c.append(Color(float(dep) / 8.0, float(skyp & 15) / 15.0, em, float(blkp & 15) / 15.0))
		else:
			buf.c.append(Color(aof, float((skyp >> (k * 4)) & 15) / 15.0, em, float((blkp >> (k * 4)) & 15) / 15.0))
		var uv: Vector2
		if d == 0:
			uv = Vector2(p.z, -p.y)
		elif d == 2:
			uv = Vector2(p.x, -p.y)
		else:
			uv = Vector2(p.x, p.z)
		buf.uv.append(uv)
		buf.uv2.append(Vector2(tile, 2.0 if ((key >> 19) & 1) == 1 else 0.0))
	var flip: bool = aos[0] + aos[2] < aos[1] + aos[3]
	if sgn > 0:
		if flip:
			buf.idx.append_array([start + 1, start + 0, start + 3, start + 1, start + 3, start + 2])
		else:
			buf.idx.append_array([start + 0, start + 3, start + 2, start + 0, start + 2, start + 1])
	else:
		if flip:
			buf.idx.append_array([start + 1, start + 2, start + 3, start + 1, start + 3, start + 0])
		else:
			buf.idx.append_array([start + 0, start + 1, start + 2, start + 0, start + 2, start + 3])


static func _box_part(buf: Buf, p0: Vector3, p1: Vector3, tile: int, em: int, ls: float, lb: float) -> void:
	var faces := [
		[Vector3(1, 0, 0), [Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p0.y, p1.z), Vector3(p1.x, p1.y, p1.z), Vector3(p1.x, p1.y, p0.z)]],
		[Vector3(-1, 0, 0), [Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p0.y, p0.z), Vector3(p0.x, p1.y, p0.z), Vector3(p0.x, p1.y, p1.z)]],
		[Vector3(0, 1, 0), [Vector3(p0.x, p1.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p1.y, p1.z), Vector3(p0.x, p1.y, p1.z)]],
		[Vector3(0, -1, 0), [Vector3(p0.x, p0.y, p1.z), Vector3(p1.x, p0.y, p1.z), Vector3(p1.x, p0.y, p0.z), Vector3(p0.x, p0.y, p0.z)]],
		[Vector3(0, 0, 1), [Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p1.y, p1.z), Vector3(p1.x, p1.y, p1.z), Vector3(p1.x, p0.y, p1.z)]],
		[Vector3(0, 0, -1), [Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p0.x, p1.y, p0.z), Vector3(p0.x, p0.y, p0.z)]],
	]
	var col := Color(0.92, ls, float(em), lb)
	for f in faces:
		var n: Vector3 = f[0]
		var pts: Array = f[1]
		var start := buf.v.size()
		for pt in pts:
			buf.v.append(pt)
			buf.n.append(n)
			buf.c.append(col)
			if absf(n.x) > 0.5:
				buf.uv.append(Vector2(pt.z, -pt.y))
			elif absf(n.z) > 0.5:
				buf.uv.append(Vector2(pt.x, -pt.y))
			else:
				buf.uv.append(Vector2(pt.x, pt.z))
			buf.uv2.append(Vector2(float(tile), 0.0))
		buf.idx.append_array([start, start + 1, start + 2, start, start + 2, start + 3])


static func _shaped_block(buf: Buf, x: int, y: int, z: int, tile: int, sh: int, em: int, ls: float, lb: float) -> void:
	var o := Vector3(x, y, z)
	# Bottom half (shared by slab and stairs)
	_box_part(buf, o, o + Vector3(1.0, 0.5, 1.0), tile, em, ls, lb)
	if sh == 2:
		# Upper step for stairs
		_box_part(buf, o + Vector3(0.0, 0.5, 0.0), o + Vector3(1.0, 1.0, 0.5), tile, em, ls, lb)


static func _plant(buf: Buf, x: int, y: int, z: int, tile: int, em: int, ls: float, lb: float) -> void:
	var quads := [
		[Vector3(x + 0.15, y, z + 0.15), Vector3(x + 0.85, y, z + 0.85)],
		[Vector3(x + 0.85, y, z + 0.15), Vector3(x + 0.15, y, z + 0.85)],
	]
	for q in quads:
		var p0: Vector3 = q[0]
		var p1: Vector3 = q[1]
		var start := buf.v.size()
		var pts := [p0, Vector3(p1.x, y, p1.z), Vector3(p1.x, y + 1, p1.z), Vector3(p0.x, y + 1, p0.z)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k in 4:
			buf.v.append(pts[k])
			buf.n.append(Vector3.UP)
			buf.c.append(Color(1.0, ls, float(em), lb))
			buf.uv.append(uvs[k])
			buf.uv2.append(Vector2(float(tile), 1.0))
		buf.idx.append_array([start, start + 1, start + 2, start, start + 2, start + 3])

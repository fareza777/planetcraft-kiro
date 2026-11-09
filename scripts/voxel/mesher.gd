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


static func mesh_sections(pd: PackedByteArray, sections: PackedInt32Array, kinds: PackedByteArray, tiles: PackedInt32Array, emis: PackedByteArray, lightr: PackedFloat32Array) -> Array:
	var top := tops(pd, kinds)
	var can := canopy(pd, kinds)
	var occ := PackedByteArray()
	occ.resize(256)
	for i in 256:
		occ[i] = 1 if (kinds[i] == K_OPAQUE or kinds[i] == K_CUTOUT) else 0
	var results := []
	for s in sections:
		results.append(_mesh_section(pd, s, kinds, tiles, emis, lightr, occ, top, can))
	return results


static func _mesh_section(pd: PackedByteArray, s: int, kinds: PackedByteArray, tiles: PackedInt32Array, emis: PackedByteArray, lightr: PackedFloat32Array, occ: PackedByteArray, top: PackedInt32Array, can: PackedInt32Array) -> Dictionary:
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
					_plant(bufs[LAYER_CUTOUT], x, y, z, tiles[id * 6], emis[id])
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
							if k != K_PLANT:
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
									var light := 15
									var sw := 0
									var ao := 0xFF
									if not (d == 1 and (ny < 0 or ny >= H)):
										var col: int = ni / H
										var ay: int = ni - col * H
										var t := top[col]
										if ay <= t:
											light = maxi(2, 15 - (t - ay) * 2)
										elif ay < can[col]:
											light = 11
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
									if layer == LAYER_CUTOUT and emis[id] == 0 and lightr[id] < 0.0:
										sw = 1
									key = (tiles[id * 6 + face] + 1) | (ao << 8) | (light << 16) | (emis[id] << 20) | (layer << 21) | (sw << 23)
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
						_quad(bufs[(key >> 21) & 3], d, u, v, sgn, i, a, b, w, h, key)
						a += w
	return {"s": s, "layers": [bufs[0].arrays(), bufs[1].arrays(), bufs[2].arrays()], "lights": lights}


static func _ao(s1: int, s2: int, c: int) -> int:
	if s1 == 1 and s2 == 1:
		return 0
	return 3 - (s1 + s2 + c)


static func _quad(buf: Buf, d: int, u: int, v: int, sgn: int, i: int, a: int, b: int, w: int, h: int, key: int) -> void:
	var tile := float((key & 0xFF) - 1)
	var ao := (key >> 8) & 0xFF
	var light := float((key >> 16) & 0xF) / 15.0
	var em := float((key >> 20) & 1)
	var layer := (key >> 21) & 3
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
		buf.c.append(Color(aof, light, em, 1.0))
		var uv: Vector2
		if d == 0:
			uv = Vector2(p.z, -p.y)
		elif d == 2:
			uv = Vector2(p.x, -p.y)
		else:
			uv = Vector2(p.x, p.z)
		buf.uv.append(uv)
		buf.uv2.append(Vector2(tile, 2.0 if ((key >> 23) & 1) == 1 else 0.0))
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


static func _plant(buf: Buf, x: int, y: int, z: int, tile: int, em: int) -> void:
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
			buf.c.append(Color(1.0, 1.0, float(em), 1.0))
			buf.uv.append(uvs[k])
			buf.uv2.append(Vector2(float(tile), 1.0))
		buf.idx.append_array([start, start + 1, start + 2, start, start + 2, start + 3])

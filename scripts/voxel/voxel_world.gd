class_name VoxelWorld
extends Node3D
## Streams chunk columns around `focus`, generating and meshing them on worker threads.
## Holds the authoritative block data for loaded chunks and the edit deltas (mods) for the
## whole planet.

const Gen := preload("res://scripts/voxel/terrain_generator.gd")
const Mesher := preload("res://scripts/voxel/mesher.gd")
const CS := 16
const H := 128
const SECT := 8

signal block_changed(pos: Vector3i, old_id: int, new_id: int)


class Column:
	var key: Vector2i
	var blocks: PackedByteArray
	var meshes: Array = [null, null, null, null, null, null, null, null]
	var lights: Array = [[], [], [], [], [], [], [], []]
	var meshed := false
	var meshing := false
	var version := 0
	var dirty := {}


var gen: Gen
var planet: Dictionary
var chunks: Dictionary = {}
var mods: Dictionary = {}
var radius := 6
var max_tasks := 3
var mesh_budget := 3
var focus := Vector3.ZERO
var lights_dirty := true

var mat_opaque: ShaderMaterial
var mat_cutout: ShaderMaterial
var mat_fluid: ShaderMaterial

var _kinds: PackedByteArray
var _tiles: PackedInt32Array
var _emis: PackedByteArray
var _lightr: PackedFloat32Array
var _solid: PackedByteArray

var _gen_pending: Dictionary = {}
var _res_gen: Array = []
var _res_mesh: Array = []
var _mutex := Mutex.new()
var _task_ids: Array = []
var _active := 0
var _center := Vector2i(1 << 30, 1 << 30)
var _want: Array = []
var _closing := false
var stats := {"gen": 0, "mesh": 0, "gen_ms": 0.0, "mesh_ms": 0.0}


func setup(p: Dictionary, world_seed: int, saved_mods: Dictionary) -> void:
	planet = p
	gen = Gen.new(p, world_seed)
	mods = saved_mods
	_kinds = Reg.kind
	_tiles = Reg.face_tiles
	_emis = Reg.emissive
	_lightr = Reg.light_radius
	_solid = Reg.solid
	var cores := OS.get_processor_count()
	max_tasks = clampi(cores - 2, 2, 6)
	mat_opaque = _mat("res://shaders/voxel_opaque.gdshader")
	mat_cutout = _mat("res://shaders/voxel_cutout.gdshader")
	mat_fluid = _mat("res://shaders/voxel_fluid.gdshader")


func _mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("tiles", Reg.tile_array)
	return m


func materials() -> Array:
	return [mat_opaque, mat_cutout, mat_fluid]


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	_closing = true
	for id in _task_ids:
		WorkerThreadPool.wait_for_task_completion(id)
	_task_ids.clear()


# ------------------------------------------------------------------ streaming

func _process(_dt: float) -> void:
	if gen == null or _closing:
		return
	_prune_tasks()
	var c := Vector2i(floori(focus.x / CS), floori(focus.z / CS))
	if c != _center:
		_center = c
		_rebuild_want()
		_unload_far()
	_collect()
	_schedule()


func _rebuild_want() -> void:
	_want.clear()
	var r := radius + 2
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz <= r * r:
				_want.append(_center + Vector2i(dx, dz))
	_want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _center).length_squared() < (b - _center).length_squared())


func _unload_far() -> void:
	var lim := (radius + 3) * (radius + 3)
	for key in chunks.keys():
		if (key - _center).length_squared() > lim:
			var col: Column = chunks[key]
			for m in col.meshes:
				if m != null:
					m.queue_free()
			chunks.erase(key)
			lights_dirty = true


func _prune_tasks() -> void:
	var keep := []
	for id in _task_ids:
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
		else:
			keep.append(id)
	_task_ids = keep


func _neighbors_ready(key: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if not chunks.has(key + Vector2i(dx, dz)):
				return false
	return true


func _in_radius(key: Vector2i) -> bool:
	var d := key - _center
	return d.x * d.x + d.y * d.y <= radius * radius + 1


func _schedule() -> void:
	# 1) edits first (responsiveness), 2) initial meshes, 3) generation
	for key in _want:
		if _active >= max_tasks:
			return
		var col: Column = chunks.get(key)
		if col != null and col.meshed and not col.meshing and not col.dirty.is_empty() and _neighbors_ready(key):
			_start_mesh(col, PackedInt32Array(col.dirty.keys()))
	for key in _want:
		if _active >= max_tasks:
			return
		var col: Column = chunks.get(key)
		if col != null and not col.meshed and not col.meshing and _in_radius(key) and _neighbors_ready(key):
			_start_mesh(col, PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7]))
	for key in _want:
		if _active >= max_tasks:
			return
		if not chunks.has(key) and not _gen_pending.has(key):
			_gen_pending[key] = true
			var m: Dictionary = mods.get(key, {}).duplicate()
			_active += 1
			_task_ids.append(WorkerThreadPool.add_task(_task_gen.bind(key, m), false, "gen"))


func _start_mesh(col: Column, sections: PackedInt32Array) -> void:
	col.dirty.clear()
	col.meshing = true
	var cols := []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var n: Column = chunks[col.key + Vector2i(dx, dz)]
			cols.append(n.blocks)
	_active += 1
	_task_ids.append(WorkerThreadPool.add_task(_task_mesh.bind(col.key, col.version, cols, sections), sections.size() < 8, "mesh"))


func _task_gen(key: Vector2i, m: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var b := gen.generate_chunk(key.x, key.y, m)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	_mutex.lock()
	_res_gen.append([key, b, dt])
	_mutex.unlock()


func _task_mesh(key: Vector2i, version: int, cols: Array, sections: PackedInt32Array) -> void:
	var t0 := Time.get_ticks_usec()
	var pd := Mesher.pad(cols)
	var res := Mesher.mesh_sections(pd, sections, _kinds, _tiles, _emis, _lightr)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	_mutex.lock()
	_res_mesh.append([key, version, res, dt])
	_mutex.unlock()


func _collect() -> void:
	_mutex.lock()
	var gens := _res_gen
	_res_gen = []
	var meshes := []
	var n := mini(_res_mesh.size(), mesh_budget)
	for i in n:
		meshes.append(_res_mesh[i])
	_res_mesh = _res_mesh.slice(n)
	_mutex.unlock()
	for r in gens:
		_active -= 1
		var key: Vector2i = r[0]
		_gen_pending.erase(key)
		stats.gen += 1
		stats.gen_ms += r[2]
		if (key - _center).length_squared() > (radius + 3) * (radius + 3):
			continue
		var col := Column.new()
		col.key = key
		col.blocks = r[1]
		chunks[key] = col
	for r in meshes:
		_active -= 1
		stats.mesh += 1
		stats.mesh_ms += r[3]
		var col: Column = chunks.get(r[0])
		if col == null:
			continue
		col.meshing = false
		col.meshed = true
		for sec in r[2]:
			_apply_section(col, sec)


func _apply_section(col: Column, sec: Dictionary) -> void:
	var s: int = sec.s
	col.lights[s] = sec.lights
	lights_dirty = true
	var layers: Array = sec.layers
	var mesh := ArrayMesh.new()
	var mats := [mat_opaque, mat_cutout, mat_fluid]
	for l in 3:
		var arr: Array = layers[l]
		if arr.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[l])
	var mi: MeshInstance3D = col.meshes[s]
	if mesh.get_surface_count() == 0:
		if mi != null:
			mi.queue_free()
			col.meshes[s] = null
		return
	if mi == null:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(col.key.x * CS, s * CS, col.key.y * CS)
		add_child(mi)
		col.meshes[s] = mi
	mi.mesh = mesh


func pending_work() -> int:
	return _active + _res_mesh.size()


func loaded_ratio() -> float:
	var total := 0
	var done := 0
	for key in _want:
		if _in_radius(key):
			total += 1
			var c: Column = chunks.get(key)
			if c != null and c.meshed:
				done += 1
	return float(done) / maxf(total, 1)


# ------------------------------------------------------------------ blocks

func get_block(x: int, y: int, z: int) -> int:
	if y < 0:
		return 12
	if y >= H:
		return 0
	var col: Column = chunks.get(Vector2i(x >> 4, z >> 4))
	if col == null:
		return -1
	return col.blocks[y + H * ((x & 15) + CS * (z & 15))]


func is_solid(x: int, y: int, z: int) -> bool:
	var id := get_block(x, y, z)
	if id < 0:
		return true
	return _solid[id] == 1


func has_chunk_at(p: Vector3) -> bool:
	return chunks.has(Vector2i(floori(p.x) >> 4, floori(p.z) >> 4))


func column_top(x: int, z: int) -> int:
	var col: Column = chunks.get(Vector2i(x >> 4, z >> 4))
	if col == null:
		return -1
	var base := H * ((x & 15) + CS * (z & 15))
	for y in range(H - 1, -1, -1):
		if _solid[col.blocks[base + y]] == 1:
			return y
	return -1


func set_block(x: int, y: int, z: int, id: int) -> bool:
	if y < 1 or y >= H:
		return false
	var key := Vector2i(x >> 4, z >> 4)
	var col: Column = chunks.get(key)
	if col == null:
		return false
	var lx := x & 15
	var lz := z & 15
	var i := y + H * (lx + CS * lz)
	var old := col.blocks[i]
	if old == id:
		return false
	var old_top := column_top(x, z)
	col.blocks[i] = id
	col.version += 1
	if not mods.has(key):
		mods[key] = {}
	mods[key][i] = id
	var s := y >> 4
	var secs := [s]
	if y % CS == 0 and s > 0:
		secs.append(s - 1)
	if y % CS == CS - 1 and s < SECT - 1:
		secs.append(s + 1)
	if y >= old_top:
		# column top changed: sky light below may change
		for k in range(0, s + 1):
			if not secs.has(k):
				secs.append(k)
	var dxs := [0]
	var dzs := [0]
	if lx == 0:
		dxs.append(-1)
	elif lx == 15:
		dxs.append(1)
	if lz == 0:
		dzs.append(-1)
	elif lz == 15:
		dzs.append(1)
	for dx in dxs:
		for dz in dzs:
			var n: Column = chunks.get(key + Vector2i(dx, dz))
			if n != null:
				for k in secs:
					n.dirty[k] = true
	if Reg.light_radius[id] > 0.0 or Reg.light_radius[old] > 0.0:
		lights_dirty = true
	block_changed.emit(Vector3i(x, y, z), old, id)
	return true


## DDA voxel raycast. Returns {} on miss or {pos, normal, id}.
func raycast(origin: Vector3, dir: Vector3, max_dist: float, include_fluid := false) -> Dictionary:
	dir = dir.normalized()
	var p := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(signi(int(signf(dir.x))), signi(int(signf(dir.y))), signi(int(signf(dir.z))))
	var t_max := Vector3.ZERO
	var t_delta := Vector3.ZERO
	for a in 3:
		if dir[a] != 0.0:
			var nb := float(p[a] + (1 if step[a] > 0 else 0))
			t_max[a] = (nb - origin[a]) / dir[a]
			t_delta[a] = absf(1.0 / dir[a])
		else:
			t_max[a] = INF
			t_delta[a] = INF
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= max_dist:
		var id := get_block(p.x, p.y, p.z)
		if id > 0:
			var k := _kinds[id]
			if k != Mesher.K_FLUID or include_fluid:
				return {"pos": p, "normal": normal, "id": id, "dist": t}
		var a := 0
		if t_max.y < t_max[a]:
			a = 1
		if t_max.z < t_max[a]:
			a = 2
		t = t_max[a]
		t_max[a] += t_delta[a]
		p[a] += step[a]
		normal = Vector3i.ZERO
		normal[a] = -step[a]
	return {}


func nearest_lights(pos: Vector3, count: int) -> Array:
	var found := []
	var c := Vector2i(floori(pos.x) >> 4, floori(pos.z) >> 4)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var col: Column = chunks.get(c + Vector2i(dx, dz))
			if col == null:
				continue
			var o := Vector3(col.key.x * CS, 0, col.key.y * CS)
			for s in SECT:
				for l in col.lights[s]:
					var wp := Vector3(l.x, l.y, l.z) + o
					found.append([wp.distance_squared_to(pos), Vector4(wp.x, wp.y, wp.z, l.w)])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := []
	for i in mini(count, found.size()):
		out.append(found[i][1])
	return out

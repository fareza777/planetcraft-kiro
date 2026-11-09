class_name Machines
extends RefCounted
## Tracks placed machine and station blocks on the current planet. Machines are always
## player-placed, so they are rebuilt from the edit deltas on load.

const H := 128

var by_type: Dictionary = {}     # machine/station type -> {Vector3i: true}


func _types_of(id: int) -> Array:
	var d := Reg.block_def(id)
	var t := []
	if d.has("machine"):
		t.append(d.machine)
	if d.has("station") and not t.has(d.station):
		t.append(d.station)
	return t


func rebuild(mods: Dictionary) -> void:
	by_type.clear()
	for key in mods:
		var m: Dictionary = mods[key]
		for i in m:
			var id: int = m[i]
			if id == 0:
				continue
			var types := _types_of(id)
			if types.is_empty():
				continue
			var y: int = i % H
			var lx: int = (i / H) % 16
			var lz: int = i / (H * 16)
			var p := Vector3i(key.x * 16 + lx, y, key.y * 16 + lz)
			for t in types:
				_add(t, p)


func _add(t: String, p: Vector3i) -> void:
	if not by_type.has(t):
		by_type[t] = {}
	by_type[t][p] = true


func on_block_changed(p: Vector3i, old_id: int, new_id: int) -> void:
	for t in _types_of(old_id):
		if by_type.has(t):
			by_type[t].erase(p)
	for t in _types_of(new_id):
		_add(t, p)


func count(t: String) -> int:
	return by_type.get(t, {}).size()


func nearest(t: String, pos: Vector3, max_dist: float) -> Variant:
	var best = null
	var bd := max_dist * max_dist
	for p in by_type.get(t, {}):
		var d := (Vector3(p) + Vector3(0.5, 0.5, 0.5)).distance_squared_to(pos)
		if d <= bd:
			bd = d
			best = p
	return best


func in_range(t: String, pos: Vector3) -> bool:
	var r := 8.0
	for p in by_type.get(t, {}):
		var id := Reg.block("o2_generator") if t == "o2" else Reg.block("heater")
		r = float(Reg.block_def(id).get("range", 8))
		if (Vector3(p) + Vector3(0.5, 0.5, 0.5)).distance_to(pos) <= r:
			return true
	return false


func stations_near(pos: Vector3, r: float) -> Array:
	var out := []
	for st in ["fabricator", "smelter", "assembler", "refinery"]:
		if nearest(st, pos, r) != null:
			out.append(st)
	return out

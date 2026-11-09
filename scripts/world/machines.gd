class_name Machines
extends Node3D
## Placed machines and stations on the current planet: power grid, storage, hydroponics,
## miner drones, auto-smelting, life-support zones. Machines are always player-placed, so
## positions are rebuilt from the edit deltas; their internal state is saved per planet.

signal produced(text: String)

const H := 128
const HYDRO_TIME := 75.0
const MINER_TIME := 14.0
const SMELT_TIME := 5.0
const ORES := ["ferrite_ore", "cuprite_ore", "aurium_ore", "titan_ore", "uranite_ore", "cobalt_ore", "meteorite"]

var world: VoxelWorld
var sky: SkyController
var by_type: Dictionary = {}     # machine/station type -> {Vector3i: true}
var state: Dictionary = {}       # Vector3i -> {"inv": [...], "t": float}
var battery := 0.0
var capacity := 0.0
var gen := 0.0
var use := 0.0
var powered := true
var _drones: Array = []
var _drone_mesh: Mesh
var _drone_mat: StandardMaterial3D


func _ready() -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.45, 0.22, 0.45)
	_drone_mesh = b
	_drone_mat = StandardMaterial3D.new()
	_drone_mat.albedo_color = Color(1.0, 0.8, 0.3)
	_drone_mat.emission_enabled = true
	_drone_mat.emission = Color(1.0, 0.7, 0.2)


func _types_of(id: int) -> Array:
	var d := Reg.block_def(id)
	var t := []
	if d.has("machine"):
		t.append(d.machine)
	if d.has("station") and not t.has(d.station):
		t.append(d.station)
	return t


func rebuild(mods: Dictionary, saved: Dictionary) -> void:
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
	state = saved.get("machines", {})
	battery = float(saved.get("battery", 0.0))
	_recount()


func _add(t: String, p: Vector3i) -> void:
	if not by_type.has(t):
		by_type[t] = {}
	by_type[t][p] = true


func on_block_changed(p: Vector3i, old_id: int, new_id: int) -> Array:
	var spilled := []
	for t in _types_of(old_id):
		if by_type.has(t):
			by_type[t].erase(p)
	if old_id != new_id and state.has(p):
		for s in state[p].get("inv", []):
			if s != null:
				spilled.append(s)
		state.erase(p)
	for t in _types_of(new_id):
		_add(t, p)
	_recount()
	return spilled


func _recount() -> void:
	capacity = count("battery") * float(Reg.block_def(Reg.block("battery")).get("capacity", 400))
	battery = minf(battery, capacity)


func count(t: String) -> int:
	return by_type.get(t, {}).size()


func positions(t: String) -> Array:
	return by_type.get(t, {}).keys()


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
	if not powered and t in ["o2", "heater"]:
		return false
	var bid := Reg.block("o2_generator") if t == "o2" else Reg.block("heater")
	var r := float(Reg.block_def(bid).get("range", 8))
	return nearest(t, pos, r) != null


func stations_near(pos: Vector3, r: float) -> Array:
	var out := []
	for st in ["fabricator", "smelter", "assembler", "refinery"]:
		if nearest(st, pos, r) != null:
			out.append(st)
	return out


func is_interactive(id: int) -> bool:
	var m: String = Reg.block_def(id).get("machine", "")
	return m in ["crate", "hydro", "miner", "smelter", "refinery", "launchpad", "terraformer", "battery", "solar", "o2", "beacon", "medbay", "reactor", "heater"]


# ---------------------------------------------------------------- storage

func storage(p: Vector3i, slots := 12) -> Array:
	if not state.has(p):
		var inv := []
		inv.resize(slots)
		state[p] = {"inv": inv, "t": 0.0}
	return state[p].inv


func store(p: Vector3i, id: String, n: int) -> int:
	var inv := storage(p)
	var mx := Inventory.stack_of(id)
	for i in inv.size():
		var s = inv[i]
		if s != null and s.id == id and s.n < mx:
			var k := mini(n, mx - int(s.n))
			s.n += k
			n -= k
			if n == 0:
				return 0
	for i in inv.size():
		if inv[i] == null:
			var k := mini(n, mx)
			inv[i] = {"id": id, "n": k}
			n -= k
			if n == 0:
				return 0
	return n


func take_all(p: Vector3i, inv: Inventory) -> int:
	var moved := 0
	var st := storage(p)
	for i in st.size():
		var s = st[i]
		if s == null:
			continue
		var left := inv.add(s.id, int(s.n))
		moved += int(s.n) - left
		if left == 0:
			st[i] = null
		else:
			s.n = left
	return moved


# ---------------------------------------------------------------- simulation

func tick(dt: float, player_pos: Vector3) -> void:
	var day := sky.daylight if sky != null else 1.0
	gen = count("solar") * float(Reg.block_def(Reg.block("solar_panel")).get("power", 6)) * day + count("reactor") * 40.0
	use = 0.0
	for t in ["o2", "heater", "smelter", "hydro", "miner", "refinery", "terraformer", "assembler", "medbay"]:
		var bid := _block_for(t)
		if bid > 0:
			use += count(t) * absf(float(Reg.block_def(bid).get("power", 0)))
	var net := gen - use
	battery = clampf(battery + net * dt, 0.0, capacity)
	powered = use <= 0.0 or net >= 0.0 or battery > 0.0
	if not powered:
		return
	_tick_hydro(dt)
	_tick_smelt(dt)
	_tick_miners(dt, player_pos)
	_tick_drones(dt)


func _block_for(t: String) -> int:
	match t:
		"o2": return Reg.block("o2_generator")
		"heater": return Reg.block("heater")
		"smelter": return Reg.block("smelter")
		"hydro": return Reg.block("hydro_tray")
		"miner": return Reg.block("miner_bay")
		"refinery": return Reg.block("refinery")
		"terraformer": return Reg.block("terraformer")
		"assembler": return Reg.block("assembler")
		"medbay": return Reg.block("medbay")
	return 0


func _tick_hydro(dt: float) -> void:
	for p in positions("hydro"):
		var st: Dictionary = state.get(p, {})
		if st.is_empty():
			storage(p, 6)
			st = state[p]
		st.t = float(st.get("t", 0.0)) + dt
		if st.t >= HYDRO_TIME:
			st.t = 0.0
			store(p, "veggie_pack" if randf() < 0.75 else "plant_fiber", 1)
			if randf() < 0.2:
				store(p, "hydro_seed", 1)


func _tick_smelt(dt: float) -> void:
	for p in positions("smelter"):
		var inv := storage(p)
		var st: Dictionary = state[p]
		var src := -1
		for i in inv.size():
			var s = inv[i]
			if s != null and _smelt_out(s.id) != "" and int(s.n) >= 2:
				src = i
				break
		if src < 0:
			st.t = 0.0
			continue
		st.t = float(st.get("t", 0.0)) + dt
		if st.t >= SMELT_TIME:
			st.t = 0.0
			var s = inv[src]
			var out := _smelt_out(s.id)
			s.n -= 2
			if s.n <= 0:
				inv[src] = null
			store(p, out, 1)


func _smelt_out(id: String) -> String:
	for r in Reg.recipes:
		if r.get("station", "") == "smelter" and r.in.size() == 1 and r.in.has(id):
			return r.out
	return ""


func _tick_miners(dt: float, player_pos: Vector3) -> void:
	for p in positions("miner"):
		storage(p)
		var st: Dictionary = state[p]
		st.t = float(st.get("t", 0.0)) + dt
		if st.t < MINER_TIME:
			continue
		st.t = 0.0
		var ore := _find_ore(p)
		if ore == Vector3i(0, -1, 0):
			continue
		var id := world.get_block(ore.x, ore.y, ore.z)
		if world.set_block(ore.x, ore.y, ore.z, 0):
			var left := store(p, Reg.block_drop(id), 1)
			if left > 0:
				produced.emit("Miner bay storage full")
			_launch_drone(Vector3(p) + Vector3(0.5, 1.2, 0.5), Vector3(ore) + Vector3(0.5, 0.5, 0.5))


func _find_ore(bay: Vector3i) -> Vector3i:
	var ore_ids := {}
	for o in ORES:
		ore_ids[Reg.block(o)] = true
	for attempt in 220:
		var q := bay + Vector3i(randi_range(-12, 12), randi_range(-24, 6), randi_range(-12, 12))
		if q.y < 2:
			continue
		var id := world.get_block(q.x, q.y, q.z)
		if ore_ids.has(id):
			return q
	return Vector3i(0, -1, 0)


func _launch_drone(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _drone_mesh
	mi.material_override = _drone_mat
	add_child(mi)
	mi.global_position = from
	_drones.append({"mi": mi, "from": from, "to": to, "t": 0.0})


func _tick_drones(dt: float) -> void:
	var keep := []
	for d in _drones:
		d.t += dt / 3.0
		var mi: MeshInstance3D = d.mi
		var k: float = d.t * 2.0 if d.t < 0.5 else (1.0 - d.t) * 2.0
		var pos: Vector3 = d.from.lerp(d.to, clampf(k, 0, 1))
		pos.y += sin(clampf(k, 0, 1) * PI) * 4.0
		mi.global_position = pos
		mi.rotation.y += dt * 8.0
		if d.t >= 1.0:
			mi.queue_free()
		else:
			keep.append(d)
	_drones = keep


## Applies production for time spent away from this planet (capped at 8 hours).
func simulate_offline(seconds: float) -> Dictionary:
	seconds = clampf(seconds, 0.0, 8.0 * 3600.0)
	var report := {"seconds": seconds, "veggies": 0, "ingots": 0, "ore": 0}
	if seconds < 30.0:
		return report
	for p in positions("hydro"):
		storage(p, 6)
		var n := int(seconds / HYDRO_TIME)
		var left := store(p, "veggie_pack", n)
		report.veggies += n - left
	for p in positions("smelter"):
		var inv := storage(p)
		for i in inv.size():
			var s = inv[i]
			if s == null:
				continue
			var out := _smelt_out(s.id)
			if out == "":
				continue
			var batches := mini(int(s.n) / 2, int(seconds / SMELT_TIME))
			if batches <= 0:
				continue
			s.n -= batches * 2
			if s.n <= 0:
				inv[i] = null
			store(p, out, batches)
			report.ingots += batches
	for p in positions("miner"):
		storage(p)
		var n := mini(int(seconds / MINER_TIME), 120)
		var ores: Array = world.planet.get("ores", [])
		for k in n:
			if ores.is_empty():
				break
			var o: Dictionary = ores[randi() % ores.size()]
			if store(p, Reg.block_drop(Reg.block(o.block)), 1) > 0:
				break
			report.ore += 1
	return report


func save_data() -> Dictionary:
	return {"machines": state, "battery": battery}

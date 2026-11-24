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
const CONVEYOR_TIME := 0.85
const TURRET_TIME := 0.85
const ORES := ["ferrite_ore", "cuprite_ore", "aurium_ore", "titan_ore", "uranite_ore", "cobalt_ore", "meteorite"]
const CARDINALS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]

var world: VoxelWorld
var sky: SkyController
var creatures: Creatures
var fx: Fx
var sfx: Sfx
var by_type: Dictionary = {}     # machine/station type -> {Vector3i: true}
var state: Dictionary = {}       # Vector3i -> {"inv": [...], "t": float}
var conveyor_dirs: Dictionary = {} # Vector3i -> int (0=N, 1=E, 2=S, 3=W)
var cable_networks: int = 0
var powered_nodes: Dictionary = {} # Vector3i -> true (machines powered via cable or proximity)
var battery := 0.0
var capacity := 0.0
var gen := 0.0
var use := 0.0
var powered := true
var _drones: Array = []
var _packets: Array = []          # visual items gliding on conveyors
var _belt_t := 0.0
var _turret_t := 0.0
var _drone_mesh: Mesh
var _drone_mat: StandardMaterial3D
var _pkt_mesh: Mesh
var _pkt_mat: StandardMaterial3D


func _ready() -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.45, 0.22, 0.45)
	_drone_mesh = b
	_drone_mat = StandardMaterial3D.new()
	_drone_mat.albedo_color = Color(1.0, 0.8, 0.3)
	_drone_mat.emission_enabled = true
	_drone_mat.emission = Color(1.0, 0.7, 0.2)
	var pb := BoxMesh.new()
	pb.size = Vector3(0.28, 0.28, 0.28)
	_pkt_mesh = pb
	_pkt_mat = StandardMaterial3D.new()
	_pkt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pkt_mat.albedo_color = Color(0.4, 0.95, 1.0)


func _types_of(id: int) -> Array:
	var d := Reg.block_def(id)
	var t := []
	if d.has("machine"):
		t.append(d.machine)
	if d.has("station") and not t.has(d.station):
		t.append(d.station)
	if d.get("conduit", false) and not t.has("cable"):
		t.append("cable")
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
	conveyor_dirs = saved.get("conveyor_dirs", {})
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
	_rebuild_power_networks()


## Flood-fill wired power networks across adjacent cables and machines. Also grants local
## proximity power within 10 blocks of any generator/battery so early crash-pod layouts work.
func _rebuild_power_networks() -> void:
	powered_nodes.clear()
	cable_networks = 0
	var all_nodes: Dictionary = {}
	for t in by_type:
		for p in by_type[t]:
			all_nodes[p] = true
	var sources := []
	for t in ["solar", "reactor", "battery"]:
		for p in positions(t):
			sources.append(p)
	var visited: Dictionary = {}
	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for src in sources:
		if visited.has(src):
			continue
		cable_networks += 1
		var q: Array = [src]
		visited[src] = true
		while not q.is_empty():
			var cur: Vector3i = q.pop_front()
			powered_nodes[cur] = true
			for d in dirs:
				var nb: Vector3i = cur + d
				if all_nodes.has(nb) and not visited.has(nb):
					visited[nb] = true
					q.append(nb)
	# Proximity fallback (10 blocks) for starter pod & compact bases without cables
	for p in all_nodes:
		if powered_nodes.has(p):
			continue
		for src in sources:
			if Vector3(p).distance_to(Vector3(src)) <= 10.5:
				powered_nodes[p] = true
				break


func is_machine_powered(p: Vector3i) -> bool:
	if not powered:
		return false
	if count("cable") == 0:
		return true
	return powered_nodes.has(p)


func set_conveyor_dir(p: Vector3i, dir_idx: int) -> void:
	conveyor_dirs[p] = posmod(dir_idx, 4)


func rotate_conveyor(p: Vector3i) -> String:
	var nd := posmod(int(conveyor_dirs.get(p, 0)) + 1, 4)
	conveyor_dirs[p] = nd
	return ["North", "East", "South", "West"][nd]


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
	for t in ["o2", "heater", "smelter", "hydro", "miner", "refinery", "terraformer", "assembler", "medbay", "turret"]:
		var bid := _block_for(t)
		if bid > 0:
			use += count(t) * absf(float(Reg.block_def(bid).get("power", 0)))
	var net := gen - use
	battery = clampf(battery + net * dt, 0.0, capacity)
	powered = use <= 0.0 or net >= 0.0 or battery > 0.0
	_tick_drones(dt)
	_tick_packets(dt)
	if not powered:
		return
	_tick_hydro(dt)
	_tick_smelt(dt)
	_tick_miners(dt, player_pos)
	_tick_conveyors(dt)
	_tick_turrets(dt)


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
		"turret": return Reg.block("turret")
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


func _take_one(p: Vector3i, smeltable_only := false) -> String:
	if not state.has(p):
		return ""
	var inv: Array = state[p].get("inv", [])
	for i in inv.size():
		var s = inv[i]
		if s == null:
			continue
		if smeltable_only and _smelt_out(s.id) == "":
			continue
		var id: String = s.id
		s.n -= 1
		if s.n <= 0:
			inv[i] = null
		return id
	return ""


func _is_storage_machine(p: Vector3i) -> bool:
	for t in ["crate", "smelter", "hydro", "miner", "conveyor"]:
		if by_type.get(t, {}).has(p):
			return true
	return false


func _tick_conveyors(dt: float) -> void:
	var belts := positions("conveyor")
	if belts.is_empty():
		return
	_belt_t += dt
	if _belt_t < CONVEYOR_TIME:
		return
	_belt_t = 0.0
	for p in belts:
		if not is_machine_powered(p):
			continue
		var d_idx: int = int(conveyor_dirs.get(p, 0))
		var fwd: Vector3i = CARDINALS[posmod(d_idx, 4)]
		var src: Vector3i = p - fwd
		var dst: Vector3i = p + fwd
		# If belt holds an item, push it forward
		var carried := _take_one(p)
		if carried != "":
			if _is_storage_machine(dst):
				if store(dst, carried, 1) == 0:
					_spawn_packet(Vector3(p) + Vector3(0.5, 1.05, 0.5), Vector3(dst) + Vector3(0.5, 1.05, 0.5))
					continue
			# couldn't push, keep on belt
			store(p, carried, 1)
		else:
			# Pull from behind (miner, hydro, smelter, crate, or prior belt)
			if _is_storage_machine(src):
				var want_smelt: bool = by_type.get("smelter", {}).has(dst)
				var item := _take_one(src, want_smelt)
				if item != "":
					store(p, item, 1)
					_spawn_packet(Vector3(src) + Vector3(0.5, 1.05, 0.5), Vector3(p) + Vector3(0.5, 1.05, 0.5))


func _spawn_packet(from: Vector3, to: Vector3) -> void:
	if _packets.size() > 24:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _pkt_mesh
	mi.material_override = _pkt_mat
	add_child(mi)
	mi.global_position = from
	_packets.append({"mi": mi, "from": from, "to": to, "t": 0.0})


func _tick_packets(dt: float) -> void:
	var keep := []
	for pk in _packets:
		pk.t += dt / CONVEYOR_TIME
		var mi: MeshInstance3D = pk.mi
		mi.global_position = pk.from.lerp(pk.to, clampf(pk.t, 0.0, 1.0))
		mi.rotation.y += dt * 4.0
		if pk.t >= 1.0:
			mi.queue_free()
		else:
			keep.append(pk)
	_packets = keep


## Powered Defense Turrets (and Colony Beacons at shorter range) shoot hostile creatures.
func _tick_turrets(dt: float) -> void:
	if creatures == null:
		return
	_turret_t += dt
	if _turret_t < TURRET_TIME:
		return
	_turret_t = 0.0
	var shooters := []
	for p in positions("turret"):
		shooters.append([p, 18.0, 14.0])
	for p in positions("beacon"):
		shooters.append([p, 12.0, 8.0])
	for sh in shooters:
		var p: Vector3i = sh[0]
		if not is_machine_powered(p):
			continue
		var origin := Vector3(p) + Vector3(0.5, 1.35, 0.5)
		var tgt := creatures.nearest_hostile(origin, float(sh[1]), null)
		if tgt != null:
			var dir := (tgt.center() - origin).normalized()
			creatures._spawn_proj(origin, dir * 32.0, float(sh[2]), "player", Color(0.35, 0.95, 1.0))
			if fx != null:
				fx.sparks(origin, Color(0.35, 0.95, 1.0), 4)
			if sfx != null and creatures.player != null:
				sfx.play_at("shoot", origin, creatures.player.global_position, -8.0, 1.35)


func save_data() -> Dictionary:
	return {"machines": state, "battery": battery, "conveyor_dirs": conveyor_dirs}

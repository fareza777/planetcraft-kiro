class_name Evolution
extends Node
## Planet Evolution: per-planet stats that change with player actions.
##   pollution  - rises with mining and smelting, greys the sky
##   atmo       - raised by powered terraformers; at 1.0 the air is breathable
##   water      - follows atmosphere; brings rain
##   life       - needs water and a Gaia Seed Vault; terraformers turn ground to soil/grass
##   colony     - level from habitat machines; colonist drones appear around beacons

signal milestone(text: String)

var stats := {"pollution": 0.0, "atmo": 0.0, "water": 0.0, "life": 0.0, "seeded": false, "catalyst": 0.0, "ann": {}}
var planet: Dictionary
var world: VoxelWorld
var machines: Machines
var _convert_t := 0.0


func setup(p: Dictionary, w: VoxelWorld, m: Machines, saved: Dictionary) -> void:
	planet = p
	world = w
	machines = m
	for k in saved:
		stats[k] = saved[k]
	if stats.atmo == 0.0:
		stats.atmo = float(p.get("o2", 0.0))


func on_mined() -> void:
	stats.pollution = minf(1.0, stats.pollution + 0.00025)


func colony_level() -> int:
	var lvl := 0
	for t in ["o2", "hydro", "solar", "battery", "medbay", "beacon", "miner", "smelter", "assembler", "refinery", "terraformer", "launchpad"]:
		if machines.count(t) > 0:
			lvl += 1
	return lvl


func tick(dt: float) -> void:
	var tf := machines.count("terraformer") if machines.powered else 0
	if tf > 0:
		var rate := 0.0008 * tf * (1.0 + float(stats.catalyst))
		stats.atmo = minf(1.0, stats.atmo + rate * dt)
		if stats.atmo > 0.3:
			stats.water = minf(1.0, stats.water + rate * 0.8 * dt)
		if stats.water > 0.3 and stats.seeded:
			stats.life = minf(1.0, stats.life + rate * 0.7 * dt)
		stats.pollution = maxf(0.0, stats.pollution - rate * 0.5 * dt)
		_convert_t -= dt
		if _convert_t <= 0.0 and stats.life > 0.02:
			_convert_t = 0.6
			for p in machines.positions("terraformer"):
				_convert_around(p)
	stats.pollution = minf(1.0, stats.pollution + machines.count("smelter") * 0.000004 * dt)
	for m in [[0.25, "atmo", "Atmosphere thickening: the sky is changing colour."], [0.5, "water", "Liquid water is condensing. Rain is possible."],
			[1.0, "atmo", "The atmosphere is breathable! Helmets off, pioneer."], [0.25, "life", "First native-compatible life is taking root."], [1.0, "life", "This world is fully alive."]]:
		var key: String = "%s_%s" % [m[1], m[0]]
		if not stats.ann.has(key) and float(stats[m[1]]) >= m[0] and float(planet.get("o2", 0.0)) < m[0]:
			stats.ann[key] = true
			milestone.emit(m[2])


func _convert_around(p: Vector3i) -> void:
	var r := int(6 + float(stats.life) * 42.0)
	var soil := Reg.block("soil")
	var grass := Reg.block("grass")
	var tuft := Reg.block("earthgrass")
	var convertible := {Reg.block("regolith"): true, Reg.block("moss"): true, Reg.block("dune_sand"): true, Reg.block("ash"): true, Reg.block("snow"): true, soil: true}
	for k in 6:
		var x := p.x + randi_range(-r, r)
		var z := p.z + randi_range(-r, r)
		if not world.has_chunk_at(Vector3(x, 0, z)):
			continue
		var top := world.column_top(x, z)
		if top <= 0:
			continue
		var id := world.get_block(x, top, z)
		if convertible.has(id):
			world.set_block(x, top, z, grass if (id == soil or randf() < float(stats.life)) else soil)
			if randf() < 0.25 and world.get_block(x, top + 1, z) == 0:
				world.set_block(x, top + 1, z, tuft)


func breathable() -> bool:
	return float(stats.atmo) >= 0.999


func temperature_bias(base: float) -> float:
	return lerpf(base, 18.0, float(stats.atmo) * 0.85)


## Returns the planet sky colours blended toward a living blue sky by atmosphere/life
## and toward grey by pollution.
func sky_colors(base: Dictionary) -> Dictionary:
	var out := {}
	var a := float(stats.atmo) - float(planet.get("o2", 0.0))
	a = clampf(a * 0.8 + float(stats.life) * 0.2, 0.0, 1.0)
	var earth := {"top": Color("2f6fd1"), "horizon": Color("a9d6ff"), "fog": Color("c4e2ff")}
	var smog := Color(0.42, 0.4, 0.38)
	for k in base:
		var c: Color = base[k]
		if earth.has(k):
			c = c.lerp(earth[k], a)
		c = c.lerp(smog, float(stats.pollution) * 0.5)
		out[k] = c
	return out


func summary() -> String:
	return "Atmosphere %d%%  ·  Water %d%%  ·  Life %d%%  ·  Pollution %d%%  ·  Colony L%d" % [
		int(stats.atmo * 100), int(stats.water * 100), int(stats.life * 100), int(stats.pollution * 100), colony_level()]

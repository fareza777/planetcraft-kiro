class_name WorldEvents
extends Node3D
## Living universe: weather rolls, storms, meteor showers, gravity anomalies.

signal announce(text: String, color: Color)

var world: VoxelWorld
var sky: SkyController
var fx: Fx
var sfx: Sfx
var player: Player
var planet: Dictionary
var evolution: Evolution
var weather := "clear"
var intensity := 0.0
var _roll_t := 90.0
var _meteor_t := 0.0
var _meteors: Array = []
var _meteor_mesh: BoxMesh
var base_gravity := 9.0


func setup(w: VoxelWorld, s: SkyController, f: Fx, sf: Sfx, p: Player, pl: Dictionary, evo: Evolution) -> void:
	world = w
	sky = s
	fx = f
	sfx = sf
	player = p
	planet = pl
	evolution = evo
	base_gravity = float(pl.get("gravity", 9.0))
	_meteor_mesh = BoxMesh.new()
	_meteor_mesh.size = Vector3(0.9, 0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.6, 0.8, 0.35)
	_meteor_mesh.material = m


func storm_color() -> Color:
	match weather:
		"dust_storm": return Color(0.75, 0.5, 0.3)
		"ash_storm": return Color(0.3, 0.22, 0.2)
		"blizzard", "snow": return Color(0.85, 0.9, 1.0)
		"spore_rain": return Color(0.6, 0.4, 0.8)
		"rain": return Color(0.45, 0.55, 0.7)
	return Color(0.5, 0.5, 0.5)


func is_storm() -> bool:
	return weather in ["dust_storm", "ash_storm", "blizzard"]


func _roll() -> void:
	var opts: Array = planet.get("weather", ["clear"]).duplicate()
	if evolution != null and float(evolution.stats.water) > 0.5:
		opts.append("rain")
	var prev := weather
	weather = opts[randi() % opts.size()]
	if weather == prev:
		return
	match weather:
		"clear": announce.emit("The skies are clearing.", Color(0.7, 0.9, 1.0))
		"dust_storm": announce.emit("⚠ Dust storm incoming! Take shelter.", Color(1, 0.7, 0.3))
		"ash_storm": announce.emit("⚠ Ash storm! Exposure burns suit integrity.", Color(1, 0.5, 0.3))
		"blizzard": announce.emit("⚠ Blizzard! Find heat and shelter.", Color(0.7, 0.9, 1.0))
		"snow": announce.emit("Snow begins to fall.", Color(0.85, 0.95, 1.0))
		"spore_rain": announce.emit("Bioluminescent spores drift down from the canopy.", Color(0.8, 0.6, 1.0))
		"rain": announce.emit("Rain! The new water cycle is working.", Color(0.6, 0.8, 1.0))
		"meteor_shower": announce.emit("☄ Meteor shower! Impacts leave rare Meteorite.", Color(1, 0.8, 0.4))
		"gravity_anomaly": announce.emit("Gravity anomaly: local gravity is unstable.", Color(0.8, 0.6, 1.0))


func _process(dt: float) -> void:
	if player == null:
		return
	_roll_t -= dt
	if _roll_t <= 0.0:
		_roll_t = randf_range(150.0, 280.0)
		_roll()
	var target := 0.0
	if weather != "clear" and weather != "meteor_shower" and weather != "gravity_anomaly":
		target = 1.0 if is_storm() else 0.35
	intensity = move_toward(intensity, target, dt * 0.15)
	sky.storm = intensity * (0.9 if is_storm() else 0.35)
	sky.storm_color = storm_color()
	fx.set_weather(weather if intensity > 0.2 else "clear", storm_color().lightened(0.3))
	sfx.loop("storm", is_storm() and intensity > 0.2, -10.0 + intensity * 6.0, 1.0, dt)
	player.gravity = base_gravity * (0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.0004) if weather == "gravity_anomaly" else 1.0)
	if weather == "meteor_shower":
		_meteor_t -= dt
		if _meteor_t <= 0.0:
			_meteor_t = randf_range(2.5, 6.0)
			_spawn_meteor()
	_update_meteors(dt)


## Storm damage for exposed players (dps).
func exposure_damage(exposed: bool) -> float:
	if not exposed or not is_storm():
		return 0.0
	return intensity * (2.5 if weather == "ash_storm" else 1.5)


func _spawn_meteor() -> void:
	var pp := player.global_position
	var a := randf() * TAU
	var d := randf_range(10.0, 38.0)
	var x := floori(pp.x + cos(a) * d)
	var z := floori(pp.z + sin(a) * d)
	if not world.has_chunk_at(Vector3(x, 0, z)):
		return
	var top := world.column_top(x, z)
	if top <= 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _meteor_mesh
	add_child(mi)
	var target := Vector3(x + 0.5, top + 1, z + 0.5)
	var start := target + Vector3(randf_range(-30, 30), 90, randf_range(-30, 30))
	mi.global_position = start
	_meteors.append({"mi": mi, "from": start, "to": target, "t": 0.0})
	sfx.play("whoosh", -6.0)


func _update_meteors(dt: float) -> void:
	var keep := []
	for m in _meteors:
		m.t += dt / 2.2
		var mi: MeshInstance3D = m.mi
		mi.global_position = m.from.lerp(m.to, m.t * m.t)
		mi.rotation += Vector3(dt * 3.0, dt * 2.0, 0)
		if randf() < 0.6:
			fx.sparks(mi.global_position, Color(1.0, 0.6, 0.2), 2)
		if m.t >= 1.0:
			_impact(m.to)
			mi.queue_free()
		else:
			keep.append(m)
	_meteors = keep


func _impact(p: Vector3) -> void:
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	var r := randi_range(2, 3)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if dx * dx + dy * dy + dz * dz <= r * r:
					var id := world.get_block(c.x + dx, c.y + dy, c.z + dz)
					if id > 0 and Reg.hardness[id] >= 0.0:
						world.set_block(c.x + dx, c.y + dy, c.z + dz, 0)
	var met := Reg.block("meteorite")
	world.set_block(c.x, c.y - r, c.z, met)
	world.set_block(c.x + 1, c.y - r, c.z, met)
	world.set_block(c.x, c.y - r + 1, c.z, met)
	fx.explosion(p, Color(1.0, 0.55, 0.2))
	var d := p.distance_to(player.global_position)
	sfx.play("explode", -d * 0.4)
	player.shake(clampf(1.2 - d / 30.0, 0.0, 1.0))
	if d < r + 1.5:
		player.stats.damage(25.0, "meteor impact")

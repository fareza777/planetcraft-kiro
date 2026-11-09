class_name Survival
extends RefCounted
## Player survival stats. update() is called every frame with an environment snapshot built
## by the world root (atmosphere, nearby machines, temperature, radiation, sunlight).

var hp := 100.0
var max_hp := 100.0
var o2 := 100.0
var max_o2 := 100.0
var energy := 100.0
var max_energy := 100.0
var food := 100.0
var rad := 0.0
var body_temp := 20.0
var upgrades := {}
var warning := ""
var last_damage := ""


func reset() -> void:
	hp = max_hp
	o2 = max_o2
	energy = max_energy
	food = maxf(food, 60.0)
	rad = 0.0


func apply_upgrades(u: Dictionary) -> void:
	if u.has("frostguard"):
		u["thermal"] = true
		u["armor"] = true
	if u.has("wyrmjet"):
		u["jet"] = true
	upgrades = u
	max_o2 = 200.0 if u.has("o2") else 100.0
	max_hp = 150.0 if u.has("armor") else 100.0


func update(dt: float, env: Dictionary) -> void:
	warning = ""
	var dmg := 0.0
	# Oxygen
	if env.get("breathable", false) or env.get("o2_zone", false):
		o2 = minf(max_o2, o2 + 25.0 * dt)
	elif env.get("in_fluid", false):
		o2 = maxf(0.0, o2 - 1.2 * dt)
	else:
		o2 = maxf(0.0, o2 - 0.42 * dt)
	if o2 <= 0.0:
		dmg += 5.0 * dt
		last_damage = "suffocation"
		warning = "OXYGEN DEPLETED"
	elif o2 < max_o2 * 0.2:
		warning = "LOW OXYGEN"
	# Food
	food = maxf(0.0, food - dt * 100.0 / 1500.0)
	if food <= 0.0:
		dmg += 1.0 * dt
		last_damage = "starvation"
		warning = "STARVING"
	# Energy
	var gain: float = env.get("sun", 0.0) * 0.9 + (6.0 if env.get("powered_zone", false) else 0.0)
	energy = clampf(energy + (gain - env.get("drain", 0.0)) * dt, 0.0, max_energy)
	# Temperature
	var ext: float = env.get("temp", 20.0)
	if env.get("heated", false):
		ext = lerpf(ext, 21.0, 0.85)
	var lo := -80.0 if upgrades.has("thermal") else -15.0
	var hi := 110.0 if upgrades.has("thermal") else 45.0
	body_temp = lerpf(body_temp, ext, clampf(dt * 0.2, 0.0, 1.0))
	if body_temp < lo:
		dmg += (lo - body_temp) * 0.06 * dt
		last_damage = "hypothermia"
		warning = "FREEZING"
	elif body_temp > hi:
		dmg += (body_temp - hi) * 0.06 * dt
		last_damage = "heatstroke"
		warning = "OVERHEATING"
	# Radiation
	var r: float = env.get("rad", 0.0)
	if upgrades.has("rad"):
		r *= 0.15
	if r > 0.0:
		rad = minf(100.0, rad + r * 4.0 * dt)
	else:
		rad = maxf(0.0, rad - 0.5 * dt)
	if rad > 60.0:
		dmg += (rad - 60.0) * 0.05 * dt
		last_damage = "radiation"
		if warning == "":
			warning = "RADIATION"
	# Hazards (magma, creatures, falls) arrive via env.damage
	var hz: float = env.get("hazard", 0.0)
	if hz > 0.0:
		dmg += hz * dt
		last_damage = env.get("hazard_name", "hazard")
	# Regeneration
	if dmg == 0.0 and food > 50.0 and o2 > 0.0:
		hp = minf(max_hp, hp + 0.5 * dt)
	hp = maxf(0.0, hp - dmg)


func damage(amount: float, reason: String) -> void:
	if upgrades.has("armor"):
		amount *= 0.7
	hp = maxf(0.0, hp - amount)
	last_damage = reason


func consume(item: Dictionary) -> bool:
	var used := false
	if item.has("food"):
		food = minf(100.0, food + float(item.food))
		used = true
	if item.has("hp"):
		hp = clampf(hp + float(item.hp), 1.0, max_hp)
		used = true
	if item.has("o2"):
		o2 = minf(max_o2, o2 + float(item.o2))
		used = true
	if item.has("energy"):
		energy = minf(max_energy, energy + float(item.energy))
		used = true
	if item.has("rad"):
		rad = maxf(0.0, rad + float(item.rad))
		used = true
	return used


func dead() -> bool:
	return hp <= 0.0


func to_data() -> Dictionary:
	return {"hp": hp, "o2": o2, "energy": energy, "food": food, "rad": rad, "temp": body_temp}


func from_data(d: Dictionary) -> void:
	hp = d.get("hp", 100.0)
	o2 = d.get("o2", 100.0)
	energy = d.get("energy", 100.0)
	food = d.get("food", 100.0)
	rad = d.get("rad", 0.0)
	body_temp = d.get("temp", 20.0)

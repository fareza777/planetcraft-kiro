class_name Creatures
extends Node3D
## Spawns and updates creatures around the player (distance-based LOD), and runs combat:
## player weapons, mining-laser damage, projectiles (pooled), loot orbs and taming.

signal killed(def_id: String)
signal tamed_creature(def_id: String)
signal boss_defeated

const NEAR := 28.0
const MID := 60.0
const DESPAWN := 76.0
const PROJ_POOL := 28

var world: VoxelWorld
var player: Player
var fx: Fx
var sfx: Sfx
var sky: SkyController
var planet: Dictionary
var gravity := 9.0
var cap := 12
var list: Array[Creature] = []
var spawn_t := 3.0
var boss_done := false
var boss_pos := Vector3(160, 0, 160)
var boss: Creature = null

var _proj: Array = []      # {mi, vel, dmg, owner, life, splash, color}
var _proj_pool: Array[MeshInstance3D] = []
var _orbs: Array = []
var _fire_cd := 0.0
var _call_t := 4.0
var _orb_mesh: BoxMesh


func setup(w: VoxelWorld, p: Player, f: Fx, s: Sfx, sk: SkyController, pl: Dictionary) -> void:
	world = w
	player = p
	fx = f
	sfx = s
	sky = sk
	planet = pl
	gravity = float(pl.get("gravity", 9.0))
	cap = 9 if OS.has_feature("mobile") else 14
	for i in PROJ_POOL:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.28
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.visible = false
		mi.top_level = true
		add_child(mi)
		_proj_pool.append(mi)
	_orb_mesh = BoxMesh.new()
	_orb_mesh.size = Vector3(0.22, 0.22, 0.22)
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.albedo_color = Color(1.0, 0.85, 0.35)
	_orb_mesh.material = om


# ---------------------------------------------------------------- spawning

func spawn(id: String, pos: Vector3, is_tamed := false) -> Creature:
	if not Reg.creatures.has(id):
		return null
	var c := Creature.new()
	add_child(c)
	c.setup(Reg.creatures[id], world, self)
	c.global_position = pos
	c.tamed = is_tamed
	c.goal = pos
	c.died.connect(_on_died)
	c.attacked_player.connect(_on_attack_player)
	c.fire_projectile.connect(_on_creature_fire)
	list.append(c)
	return c


func _try_spawn() -> void:
	var wild := 0
	for c in list:
		if not c.tamed:
			wild += 1
	if wild >= cap:
		return
	var table: Array = planet.get("creatures", [])
	if table.is_empty():
		return
	var night := sky.is_night()
	var opts := []
	var total := 0.0
	for e in table:
		if e.get("night", false) and not night:
			continue
		var w := float(e.w)
		if night and Reg.creatures.get(e.id, {}).get("behavior", "") == "hostile":
			w *= 2.0
		opts.append([e.id, w])
		total += w
	if opts.is_empty():
		return
	var r := randf() * total
	var pick: String = opts[0][0]
	for o in opts:
		r -= o[1]
		if r <= 0.0:
			pick = o[0]
			break
	var a := randf() * TAU
	var dist := randf_range(22.0, 42.0)
	var pp := player.global_position
	var x := floori(pp.x + cos(a) * dist)
	var z := floori(pp.z + sin(a) * dist)
	if not world.has_chunk_at(Vector3(x, 0, z)):
		return
	var top := world.column_top(x, z)
	if top <= 0:
		return
	var above := world.get_block(x, top + 1, z)
	if above > 0 and Reg.kind[above] == Reg.Kind.FLUID:
		return
	var def: Dictionary = Reg.creatures[pick]
	var y := top + 1.0 + (5.0 if def.get("fly", false) else 0.0)
	var n := 1 if def.get("behavior", "") == "hostile" else randi_range(1, 3)
	for k in n:
		spawn(pick, Vector3(x + 0.5 + k * 1.2, y, z + 0.5 + k * 0.8))


func _check_boss() -> void:
	if boss_done or not planet.has("boss") or (boss != null and is_instance_valid(boss)):
		return
	var pp := player.global_position
	if Vector2(pp.x - boss_pos.x, pp.z - boss_pos.z).length() < 40.0:
		boss = spawn(planet.boss, Vector3(boss_pos.x, pp.y + 10.0, boss_pos.z))
		if boss != null:
			sfx.play("growl", 4.0, 0.6)
			player.shake(0.6)


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	if player == null:
		return
	dt = minf(dt, 0.05)
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = 2.5
		_try_spawn()
		_check_boss()
	var pp := player.global_position
	var removed: Array[Creature] = []
	for c in list:
		if not is_instance_valid(c):
			removed.append(c)
			continue
		var d := c.global_position.distance_to(pp)
		if d > DESPAWN and not c.tamed and c != boss:
			removed.append(c)
			c.queue_free()
			continue
		if not world.has_chunk_at(c.global_position):
			continue
		if d < NEAR or c.tamed or c == boss:
			c.tick(dt, player, true)
		elif d < MID:
			c.lod_skip += dt
			if c.lod_skip >= 0.15:
				c.tick(c.lod_skip, player, false)
				c.lod_skip = 0.0
	for c in removed:
		list.erase(c)
	_call_t -= dt
	if _call_t <= 0.0 and not list.is_empty():
		_call_t = randf_range(5.0, 11.0)
		var c: Creature = list[randi() % list.size()]
		if is_instance_valid(c) and c.alive:
			sfx.play_at(c.def.get("call", "call_low"), c.global_position, pp, -4.0, 1.0 / sqrt(c.size))
	_fire_cd -= dt
	_update_projectiles(dt)
	_update_orbs(dt)


func nearest_hostile(pos: Vector3, r: float, exclude: Creature) -> Creature:
	var best: Creature = null
	var bd := r
	for c in list:
		if c == exclude or not is_instance_valid(c) or not c.alive or c.tamed:
			continue
		if c.def.get("behavior", "") == "passive":
			continue
		var d := c.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = c
	return best


# ---------------------------------------------------------------- player combat

## Ray vs creature bodies. Returns the first creature within `reach` along the ray.
func ray_creature(origin: Vector3, dir: Vector3, reach: float) -> Creature:
	var best: Creature = null
	var bt := reach
	for c in list:
		if not is_instance_valid(c) or not c.alive or c.tamed:
			continue
		var cc := c.center()
		var r := maxf(c.half, 0.35) + 0.25 + c.height * 0.25
		var oc := cc - origin
		var t := oc.dot(dir)
		if t < 0.0 or t > bt:
			continue
		if (oc - dir * t).length() < r:
			bt = t
			best = c
	return best


## Called by the player while "mine" is held with a tool: the laser hurts creatures.
func laser_tick(dt: float, dmg: float) -> Creature:
	var c := ray_creature(player.eye_pos(), player.look_dir(), Player.REACH + 2.0)
	if c != null:
		c.hit(dmg * dt * 2.5, player.global_position)
		if randf() < dt * 8.0:
			fx.sparks(c.center(), Color(0.5, 0.95, 1.0), 4)
	return c


## Called by the player while "mine" is held with a weapon selected.
func fire_weapon(it: Dictionary) -> void:
	if _fire_cd > 0.0:
		return
	var w: Dictionary = it.weapon
	var cost := float(w.get("energy", 1.0))
	if player.stats.energy < cost:
		player.toast.emit("Weapon needs suit energy", Color(1, 0.6, 0.3))
		_fire_cd = 0.5
		return
	_fire_cd = float(w.get("rate", 0.4))
	player.stats.energy -= cost
	player.recoil(0.06 if not w.get("melee", false) else 0.12)
	if w.get("melee", false):
		sfx.play("swing", -2.0)
		var hit_any := false
		for c in list:
			if not is_instance_valid(c) or not c.alive or c.tamed:
				continue
			var to := c.center() - player.eye_pos()
			if to.length() < 3.2 + c.half and to.normalized().dot(player.look_dir()) > 0.45:
				_damage_creature(c, float(w.dmg), Color(0.6, 0.95, 1.0))
				hit_any = true
		if hit_any:
			player.shake(0.15)
		return
	var dir := player.look_dir()
	var from := player.hand.global_position + dir * 0.4
	var col := Color.html(w.get("color", "#4fe3ff"))
	_spawn_proj(from, dir * float(w.get("speed", 40.0)), float(w.dmg), "player", col, float(w.get("splash", 0.0)))
	sfx.play("shoot_heavy" if w.has("splash") else "shoot", -4.0)


func _damage_creature(c: Creature, dmg: float, col: Color) -> void:
	var crit := randf() < 0.12
	var d := dmg * (2.0 if crit else 1.0)
	c.hit(d, player.global_position)
	fx.number(c.center() + Vector3(0, c.height * 0.5, 0), ("%d!" % int(d)) if crit else str(int(d)), Color(1, 0.85, 0.3) if crit else Color.WHITE)
	fx.sparks(c.center(), col, 8)
	sfx.play("hit", -3.0)


func try_tame() -> bool:
	var c := ray_creature(player.eye_pos(), player.look_dir(), 7.0)
	if c == null or c.def.get("tame", "") == "":
		return false
	c.tamed = true
	c.state = "follow"
	c.hp = c.max_hp
	c.hp_bar.visible = false
	fx.sparks(c.center(), Color(0.5, 1.0, 0.6), 20)
	sfx.play("quest", -2.0)
	tamed_creature.emit(c.def.id)
	return true


# ---------------------------------------------------------------- projectiles

func _spawn_proj(from: Vector3, v: Vector3, dmg: float, owner: String, col: Color, splash := 0.0) -> void:
	var mi: MeshInstance3D = null
	for m in _proj_pool:
		if not m.visible:
			mi = m
			break
	if mi == null:
		return
	mi.visible = true
	mi.global_position = from
	(mi.material_override as StandardMaterial3D).albedo_color = col * 1.5
	mi.scale = Vector3.ONE * (1.8 if splash > 0.0 else 1.0)
	_proj.append({"mi": mi, "vel": v, "dmg": dmg, "owner": owner, "life": 2.0, "splash": splash, "col": col})


func _on_creature_fire(c: Creature, from: Vector3, dir: Vector3) -> void:
	var col := Color.html(c.def.c[2])
	_spawn_proj(from, dir * (16.0 if c.def.get("boss", false) else 13.0), float(c.def.dmg), "enemy", col)
	if c.def.get("boss", false):
		for k in 2:
			var side := dir.rotated(Vector3.UP, (k * 2 - 1) * 0.25)
			_spawn_proj(from, side * 14.0, float(c.def.dmg) * 0.7, "enemy", col)
	sfx.play_at("shoot", from, player.global_position, -6.0, 0.7)


func _update_projectiles(dt: float) -> void:
	var keep := []
	var pc := player.global_position + Vector3(0, 0.9, 0)
	for p in _proj:
		var mi: MeshInstance3D = p.mi
		var old := mi.global_position
		var np: Vector3 = old + p.vel * dt
		p.life -= dt
		var done: bool = p.life <= 0.0
		if not done and world.is_solid(floori(np.x), floori(np.y), floori(np.z)):
			done = true
			fx.sparks(old, p.col, 6)
		if not done and p.owner == "player":
			for c in list:
				if is_instance_valid(c) and c.alive and not c.tamed and c.center().distance_to(np) < maxf(c.half, 0.4) + 0.45 + c.height * 0.2:
					_damage_creature(c, p.dmg, p.col)
					done = true
					break
		elif not done and p.owner == "enemy" and np.distance_to(pc) < 0.8:
			_hurt_player(p.dmg, "energy bolt")
			done = true
		if done:
			if p.splash > 0.0:
				fx.explosion(np, p.col)
				sfx.play("explode", -2.0)
				for c in list:
					if is_instance_valid(c) and c.alive and not c.tamed and c.center().distance_to(np) < p.splash + c.half:
						_damage_creature(c, p.dmg * 0.6, p.col)
				player.shake(0.25)
			mi.visible = false
		else:
			mi.global_position = np
			keep.append(p)
	_proj = keep


func _on_attack_player(c: Creature, dmg: float) -> void:
	_hurt_player(dmg, c.def.name)


func _hurt_player(dmg: float, reason: String) -> void:
	player.stats.damage(dmg, reason)
	player.shake(0.35)
	sfx.play("hurt", 0.0)


# ---------------------------------------------------------------- death and loot

func _on_died(c: Creature) -> void:
	fx.explosion(c.center(), Color.html(c.def.c[2]))
	fx.debris(Vector3i(c.center().floor()), Color.html(c.def.c[0]))
	sfx.play_at("die", c.global_position, player.global_position, 0.0, 1.0 / sqrt(c.size))
	var items := []
	for d in c.def.get("drops", []):
		var n := randi_range(int(d[1]), int(d[2]))
		if n > 0:
			items.append([d[0], n])
	for i in items.size():
		var orb := MeshInstance3D.new()
		orb.mesh = _orb_mesh
		orb.top_level = true
		add_child(orb)
		orb.global_position = c.center() + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
		_orbs.append({"mi": orb, "item": items[i], "t": 0.0, "v": Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2))})
	player.xp += int(c.def.get("xp", 1))
	if c == boss:
		boss_done = true
		boss_defeated.emit()
	killed.emit(c.def.id)
	list.erase(c)
	c.queue_free()


func _update_orbs(dt: float) -> void:
	var keep := []
	var target := player.global_position + Vector3(0, 1.0, 0)
	for o in _orbs:
		o.t += dt
		var mi: MeshInstance3D = o.mi
		if o.t < 0.5:
			o.v.y -= 9.0 * dt
			mi.global_position += o.v * dt
		else:
			mi.global_position = mi.global_position.move_toward(target, dt * (6.0 + o.t * 14.0))
		mi.rotation.y += dt * 5.0
		if o.t > 0.5 and mi.global_position.distance_to(target) < 0.5:
			player.inv.add(o.item[0], o.item[1])
			player.toast.emit("+%d %s" % [o.item[1], Reg.item_label(o.item[0])], Color(1, 0.85, 0.35))
			sfx.play("pickup", -4.0)
			mi.queue_free()
		else:
			keep.append(o)
	_orbs = keep


func pets_data() -> Array:
	var out := []
	for c in list:
		if is_instance_valid(c) and c.tamed:
			out.append({"id": c.def.id, "pos": c.global_position})
	return out

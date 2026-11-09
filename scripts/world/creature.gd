class_name Creature
extends Node3D
## One alien creature: voxel-part body built from its data definition, procedural animation,
## AABB-vs-voxel movement and a small state machine. Driven by Creatures (the manager).

signal died(c: Creature)
signal attacked_player(c: Creature, dmg: float)
signal fire_projectile(c: Creature, from: Vector3, dir: Vector3)

var def: Dictionary
var world: VoxelWorld
var mgr: Node
var hp := 10.0
var max_hp := 10.0
var vel := Vector3.ZERO
var state := "wander"
var tamed := false
var goal := Vector3.ZERO
var prey: Creature = null
var think_t := 0.0
var attack_cd := 0.0
var shoot_cd := 1.0
var flee_t := 0.0
var phase := 0.0
var flash := 0.0
var on_ground := false
var fly := false
var half := 0.4
var height := 1.0
var speed := 3.0
var size := 1.0
var alive := true
var lod_skip := 0.0
var hover := 5.0

var pivot: Node3D
var legs: Array[Node3D] = []
var wings: Array[Node3D] = []
var segments: Array[Node3D] = []
var rings: Array[Node3D] = []
var _body_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _boxes: Dictionary = {}
var _trail: Array[Vector3] = []
var hp_bar: MeshInstance3D


func setup(d: Dictionary, w: VoxelWorld, m: Node) -> void:
	def = d
	world = w
	mgr = m
	size = float(d.get("size", 1.0))
	max_hp = float(d.get("hp", 30))
	hp = max_hp
	speed = float(d.get("speed", 3.0))
	fly = d.get("fly", false)
	half = 0.32 * size
	height = 0.9 * size
	hover = randf_range(3.5, 7.0)
	_build()


# ---------------------------------------------------------------- body

## Parts are recorded per animated joint and merged into one mesh per (joint, glow) pair,
## so a creature costs a handful of draw calls instead of one per box.
func _mat(c: Color, glow := false) -> Dictionary:
	return {"c": c * 1.3 if glow else c, "glow": glow}


func _part(parent: Node3D, sz: Vector3, pos: Vector3, m: Dictionary, rot := Vector3.ZERO) -> void:
	if not _boxes.has(parent):
		_boxes[parent] = []
	_boxes[parent].append([sz, pos, rot, m.c, m.glow])


const _FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
]


func _finalize() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.vertex_color_use_as_albedo = true
	_body_mat.roughness = 0.85
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0, 0, 0)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for parent in _boxes:
		for glow in [false, true]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var any := false
			for b in _boxes[parent]:
				if b[4] != glow:
					continue
				any = true
				var basis := Basis.from_euler(b[2])
				var h: Vector3 = b[0] * 0.5
				var col: Color = b[3]
				for f in _FACES:
					var n: Vector3 = f[0]
					var u: Vector3 = f[1]
					var v: Vector3 = f[2]
					var hn := absf(h.dot(n))
					var hu := absf(h.dot(u))
					var hv := absf(h.dot(v))
					var shade := 1.0 if n.y > 0.5 else (0.6 if n.y < -0.5 else 0.82)
					var c := Color(col.r * shade, col.g * shade, col.b * shade) if not glow else col
					var cs := []
					for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
						var lp: Vector3 = n * hn + u * hu * k[0] + v * hv * k[1]
						cs.append(basis * lp + b[1])
					var wn: Vector3 = basis * n
					for idx in [0, 2, 1, 0, 3, 2]:
						st.set_color(c)
						st.set_normal(wn)
						st.add_vertex(cs[idx])
			if any:
				var mi := MeshInstance3D.new()
				mi.mesh = st.commit()
				mi.material_override = _glow_mat if glow else _body_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(mi)
	_boxes.clear()


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _build() -> void:
	var cols: Array = def.get("c", ["#888888", "#444444", "#ffffff"])
	var c0 := Color.html(cols[0])
	var c1 := Color.html(cols[1])
	var c2 := Color.html(cols[2])
	var mb := _mat(c0)
	var ma := _mat(c1)
	var mg := _mat(c2, true)
	pivot = Node3D.new()
	add_child(pivot)
	var s := size
	match def.get("plan", "quad"):
		"quad":
			var lanky: bool = def.get("lanky", false)
			var leg_h := (0.75 if lanky else 0.45) * s
			var torso := Vector3(0.7 * s, 0.5 * s, 1.15 * s) if not lanky else Vector3(0.5 * s, 0.4 * s, 1.1 * s)
			height = leg_h + torso.y + 0.1 * s
			_part(pivot, torso, Vector3(0, leg_h + torso.y * 0.5, 0), mb)
			_part(pivot, Vector3(torso.x * 0.9, 0.12 * s, torso.z * 0.8), Vector3(0, leg_h + torso.y + 0.04 * s, 0), ma)
			var head := _joint(pivot, Vector3(0, leg_h + torso.y * 0.75, -torso.z * 0.55))
			_part(head, Vector3(0.45 * s, 0.4 * s, 0.45 * s), Vector3(0, 0, -0.15 * s), mb)
			_part(head, Vector3(0.08 * s, 0.08 * s, 0.05 * s), Vector3(-0.12 * s, 0.06 * s, -0.38 * s), mg)
			_part(head, Vector3(0.08 * s, 0.08 * s, 0.05 * s), Vector3(0.12 * s, 0.06 * s, -0.38 * s), mg)
			segments.append(head)
			for k in 3:
				_part(pivot, Vector3(0.12, 0.12, 0.12) * s, Vector3(randf_range(-0.2, 0.2) * s, leg_h + torso.y + 0.12 * s, (k - 1) * 0.3 * s), mg)
			for lx in [-1, 1]:
				for lz in [-1, 1]:
					var j := _joint(pivot, Vector3(lx * torso.x * 0.38, leg_h, lz * torso.z * 0.38))
					_part(j, Vector3(0.16 * s, leg_h, 0.16 * s), Vector3(0, -leg_h * 0.5, 0), ma)
					legs.append(j)
			_part(pivot, Vector3(0.12 * s, 0.12 * s, 0.5 * s), Vector3(0, leg_h + torso.y * 0.6, torso.z * 0.7), mb)
		"crawler":
			height = 0.45 * s
			_part(pivot, Vector3(0.7 * s, 0.25 * s, 0.9 * s), Vector3(0, 0.28 * s, 0), mb)
			_part(pivot, Vector3(0.5 * s, 0.2 * s, 0.35 * s), Vector3(0, 0.3 * s, -0.55 * s), ma)
			_part(pivot, Vector3(0.07, 0.07, 0.07) * s, Vector3(-0.12 * s, 0.4 * s, -0.7 * s), mg)
			_part(pivot, Vector3(0.07, 0.07, 0.07) * s, Vector3(0.12 * s, 0.4 * s, -0.7 * s), mg)
			for k in 3:
				for lx in [-1, 1]:
					var j := _joint(pivot, Vector3(lx * 0.33 * s, 0.3 * s, (k - 1) * 0.3 * s))
					_part(j, Vector3(0.45 * s, 0.07 * s, 0.07 * s), Vector3(lx * 0.22 * s, -0.12 * s, 0), ma, Vector3(0, 0, lx * 0.6))
					legs.append(j)
		"flyer":
			height = 0.4 * s
			_part(pivot, Vector3(0.55 * s, 0.18 * s, 1.0 * s), Vector3.ZERO, mb)
			_part(pivot, Vector3(0.1 * s, 0.1 * s, 0.8 * s), Vector3(0, 0, 0.85 * s), ma)
			_part(pivot, Vector3(0.08, 0.06, 0.06) * s, Vector3(-0.14 * s, 0.08 * s, -0.5 * s), mg)
			_part(pivot, Vector3(0.08, 0.06, 0.06) * s, Vector3(0.14 * s, 0.08 * s, -0.5 * s), mg)
			for wx in [-1, 1]:
				var j := _joint(pivot, Vector3(wx * 0.27 * s, 0, 0))
				_part(j, Vector3(0.9 * s, 0.05 * s, 0.75 * s), Vector3(wx * 0.45 * s, 0, 0.05 * s), ma)
				_part(j, Vector3(0.5 * s, 0.06 * s, 0.1 * s), Vector3(wx * 0.5 * s, 0.01, -0.2 * s), mg)
				wings.append(j)
		"hopper":
			height = 0.8 * s
			_part(pivot, Vector3(0.8, 0.7, 0.8) * s, Vector3(0, 0.35 * s, 0), mb)
			_part(pivot, Vector3(0.5, 0.35, 0.5) * s, Vector3(0, 0.45 * s, 0), mg)
			_part(pivot, Vector3(0.12, 0.12, 0.06) * s, Vector3(-0.18 * s, 0.5 * s, -0.42 * s), ma)
			_part(pivot, Vector3(0.12, 0.12, 0.06) * s, Vector3(0.18 * s, 0.5 * s, -0.42 * s), ma)
		"serpent":
			height = 0.6 * s
			var head := _joint(pivot, Vector3(0, 0.3 * s, 0))
			_part(head, Vector3(0.65, 0.55, 0.8) * s, Vector3.ZERO, mb)
			_part(head, Vector3(0.1, 0.1, 0.05) * s, Vector3(-0.2 * s, 0.15 * s, -0.42 * s), mg)
			_part(head, Vector3(0.1, 0.1, 0.05) * s, Vector3(0.2 * s, 0.15 * s, -0.42 * s), mg)
			_part(head, Vector3(0.5, 0.12, 0.3) * s, Vector3(0, -0.2 * s, -0.35 * s), ma)
			for k in 9:
				var seg := Node3D.new()
				add_child(seg)
				seg.top_level = true
				var ss := (1.0 - k * 0.07) * s
				_part(seg, Vector3(0.55, 0.45, 0.6) * ss, Vector3(0, 0.25 * ss, 0), mb if k % 2 == 0 else ma)
				if k % 2 == 0:
					_part(seg, Vector3(0.15, 0.15, 0.15) * ss, Vector3(0, 0.52 * ss, 0), mg)
				segments.append(seg)
		"drone":
			height = 0.8 * s
			_part(pivot, Vector3(0.6, 0.6, 0.6) * s, Vector3.ZERO, mb)
			_part(pivot, Vector3(0.25, 0.25, 0.08) * s, Vector3(0, 0, -0.32 * s), mg)
			var r := _joint(pivot, Vector3.ZERO)
			for k in 4:
				var a := k * PI / 2.0
				_part(r, Vector3(0.95 * s, 0.08 * s, 0.1 * s), Vector3(cos(a) * 0.5 * s, 0, sin(a) * 0.5 * s), ma, Vector3(0, -a + PI / 2, 0))
			rings.append(r)
		"boss":
			height = 2.4 * s * 0.5
			_part(pivot, Vector3(1.4, 1.4, 1.4) * s * 0.5, Vector3.ZERO, mb)
			_part(pivot, Vector3(0.7, 0.7, 0.7) * s * 0.5, Vector3(0, 0, -0.4 * s * 0.5), mg)
			for rr in 2:
				var r := _joint(pivot, Vector3.ZERO)
				r.rotation.x = rr * PI / 2.5
				for k in 8:
					var a := k * TAU / 8.0
					_part(r, Vector3(0.5, 0.18, 0.18) * s * 0.5, Vector3(cos(a), 0, sin(a)) * 1.6 * s * 0.5, mg if k % 2 == 0 else ma, Vector3(0, -a, 0))
				rings.append(r)
			half = 0.8 * s * 0.5
	_finalize()
	_build_hp_bar()


func _build_hp_bar() -> void:
	hp_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.09)
	hp_bar.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.albedo_color = Color(1, 0.3, 0.35) if def.get("behavior", "") == "hostile" else Color(0.5, 1, 0.6)
	hp_bar.material_override = m
	hp_bar.position = Vector3(0, height + 0.45, 0)
	hp_bar.visible = false
	add_child(hp_bar)
	if def.get("elite", false) or def.get("boss", false):
		m.albedo_color = Color(1.0, 0.75, 0.2)
		var tag := Label3D.new()
		tag.text = ("★ " if def.get("elite", false) else "☠ ") + String(def.name).to_upper()
		tag.font_size = 44
		tag.outline_size = 10
		tag.pixel_size = 0.007
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color(1.0, 0.78, 0.25)
		tag.position = Vector3(0, height + 0.85, 0)
		add_child(tag)
		_glow_mat.albedo_color = Color(1.4, 1.1, 0.5)


# ---------------------------------------------------------------- combat

func hit(dmg: float, from: Vector3) -> void:
	if not alive:
		return
	hp -= dmg
	flash = 0.12
	var away := global_position - from
	away.y = 0
	if away.length() > 0.01:
		vel += away.normalized() * (4.0 / maxf(size, 0.6)) + Vector3(0, 2.0 if not fly else 0.5, 0)
	hp_bar.visible = true
	(hp_bar.mesh as QuadMesh).size.x = maxf(0.02, hp / max_hp) * minf(1.0 + size * 0.3, 3.0)
	if def.behavior == "passive" and not tamed:
		state = "flee"
		flee_t = 5.0
	elif not tamed:
		state = "chase"
	if hp <= 0.0:
		alive = false
		died.emit(self)


func center() -> Vector3:
	return global_position + Vector3(0, height * 0.5, 0)


# ---------------------------------------------------------------- update

func tick(dt: float, player: Player, near: bool) -> void:
	if not alive:
		return
	attack_cd -= dt
	shoot_cd -= dt
	flee_t -= dt
	think_t -= dt
	var ppos := player.global_position
	var d := global_position.distance_to(ppos)
	if think_t <= 0.0:
		think_t = randf_range(0.25, 0.7)
		_think(player, d)
	var tgt := goal
	var want := Vector3.ZERO
	var spd := speed
	match state:
		"wander":
			spd = speed * 0.45
		"flee":
			spd = speed * 1.3
		"chase", "follow":
			spd = speed
	if state == "chase":
		tgt = prey.global_position if (prey != null and is_instance_valid(prey) and prey.alive) else ppos
	elif state == "follow":
		tgt = ppos
	var to := tgt - global_position
	var flat := Vector3(to.x, 0, to.z)
	var stop := 0.4
	if state == "follow":
		stop = 3.5
	elif state == "chase":
		stop = (7.0 if def.get("ranged", false) else half + 0.9)
	if flat.length() > stop:
		want = flat.normalized() * spd
	elif state == "chase" and def.get("ranged", false) and flat.length() < 5.0:
		want = -flat.normalized() * spd * 0.6
	# attack
	if state == "chase":
		var tgt_center := tgt + Vector3(0, 0.9, 0)
		if def.get("ranged", false):
			if shoot_cd <= 0.0 and to.length() < 22.0:
				shoot_cd = 0.6 if def.get("boss", false) else 1.7
				var from := center()
				fire_projectile.emit(self, from, (tgt_center - from).normalized())
		elif to.length() < half + 1.4 and attack_cd <= 0.0:
			attack_cd = 1.1
			if prey != null and is_instance_valid(prey):
				prey.hit(float(def.dmg), global_position)
			else:
				attacked_player.emit(self, float(def.dmg))
			vel += flat.normalized() * 3.0
	if fly:
		_move_fly(dt, want, tgt)
	else:
		_move_ground(dt, want)
	if want.length() > 0.1:
		var yaw := atan2(-want.x, -want.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(dt * 6.0, 1.0))
	if near:
		_animate(dt)
	if flash > 0.0:
		flash -= dt
		_body_mat.emission = Color(1, 1, 1) * (0.9 if flash > 0.0 else 0.0)


func _think(player: Player, d: float) -> void:
	var beh: String = def.get("behavior", "passive")
	if tamed:
		prey = mgr.nearest_hostile(player.global_position, 14.0, self) if mgr != null else null
		state = "chase" if prey != null else "follow"
		return
	prey = null
	if state == "flee" and flee_t > 0.0:
		var away := global_position - player.global_position
		away.y = 0
		goal = global_position + away.normalized() * 10.0
		return
	var aggro := float(def.get("aggro", 0))
	if beh == "hostile" and d < aggro:
		state = "chase"
	elif beh == "territorial" and d < aggro:
		state = "chase"
	elif state == "chase" and d > aggro * 1.6 + 6.0:
		state = "wander"
	elif state != "chase":
		state = "wander"
		if randf() < 0.35 or global_position.distance_to(goal) < 1.0:
			goal = global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))


func _move_ground(dt: float, want: Vector3) -> void:
	var g: float = mgr.gravity if mgr != null else 9.0
	var accel := 10.0 if on_ground else 2.0
	vel.x = move_toward(vel.x, want.x, accel * dt * maxf(speed, 1.0))
	vel.z = move_toward(vel.z, want.z, accel * dt * maxf(speed, 1.0))
	if def.get("plan", "") == "hopper":
		if on_ground and want.length() > 0.1:
			vel.y = sqrt(2.0 * g * 1.1)
			on_ground = false
	vel.y = maxf(vel.y - g * dt, -40.0)
	var was := on_ground
	on_ground = false
	var bx := _move(0, vel.x * dt)
	var bz := _move(2, vel.z * dt)
	_move(1, vel.y * dt)
	if (bx or bz) and (on_ground or was) and want.length() > 0.1:
		vel.y = sqrt(2.0 * g * 1.25)
	if global_position.y < -20:
		alive = false
		died.emit(self)


func _move_fly(dt: float, want: Vector3, tgt: Vector3) -> void:
	var p := global_position
	var top := world.column_top(floori(p.x), floori(p.z))
	var alt := float(top) + hover
	if state == "chase":
		alt = maxf(tgt.y + 2.5, float(top) + 1.5)
	var vy := clampf((alt - p.y) * 1.5, -4.0, 4.0)
	var target_v := Vector3(want.x, vy, want.z)
	vel = vel.lerp(target_v, minf(dt * 2.5, 1.0))
	var np := p + vel * dt
	if world.is_solid(floori(np.x), floori(np.y), floori(np.z)):
		vel.y = 4.0
		np = p + Vector3(0, vel.y * dt, 0)
	global_position = np


func _move(axis: int, d: float) -> bool:
	if d == 0.0:
		return false
	var p := global_position
	p[axis] += d
	var mn := Vector3(p.x - half, p.y, p.z - half)
	var mx := Vector3(p.x + half, p.y + height, p.z + half)
	for x in range(floori(mn.x), floori(mx.x - 0.0001) + 1):
		for y in range(floori(mn.y), floori(mx.y - 0.0001) + 1):
			for z in range(floori(mn.z), floori(mx.z - 0.0001) + 1):
				if world.is_solid(x, y, z):
					if axis == 1:
						if d < 0:
							global_position.y = y + 1.0
							on_ground = true
						vel.y = 0.0
					elif axis == 0:
						vel.x = 0.0
					else:
						vel.z = 0.0
					return true
	global_position = p
	return false


func _animate(dt: float) -> void:
	var hv := Vector2(vel.x, vel.z).length()
	phase += dt * (2.0 + hv * 3.5)
	var amp := clampf(hv / maxf(speed, 0.1), 0.0, 1.0)
	for i in legs.size():
		var off := 0.0 if (i % 2 == 0) else PI
		if def.plan == "crawler":
			off = i * 1.3
		legs[i].rotation.x = sin(phase + off) * 0.7 * amp
	for i in wings.size():
		var sgn := -1.0 if i == 0 else 1.0
		wings[i].rotation.z = sgn * sin(phase * 1.6) * 0.55
	for r in rings:
		r.rotation.y += dt * (2.5 if def.get("boss", false) else 4.0)
	match def.plan:
		"quad":
			pivot.position.y = absf(sin(phase)) * 0.05 * size * amp
			if segments.size() > 0:
				segments[0].rotation.x = sin(phase * 0.5) * 0.12
		"hopper":
			var sq := clampf(1.0 + vel.y * 0.04, 0.7, 1.35)
			pivot.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
		"flyer", "drone", "boss":
			pivot.position.y = sin(phase * 0.8) * 0.15
		"serpent":
			_trail.push_front(global_position)
			if _trail.size() > 60:
				_trail.pop_back()
			for k in segments.size():
				var seg := segments[k]
				var idx := mini((k + 1) * 5, _trail.size() - 1)
				var tp := _trail[idx]
				var wob := sin(phase - k * 0.7) * 0.25 * amp
				seg.global_position = tp + global_transform.basis.x * wob
				var nxt := _trail[maxi(idx - 5, 0)]
				if nxt.distance_to(tp) > 0.01:
					seg.look_at(Vector3(nxt.x, tp.y, nxt.z) if absf(nxt.y - tp.y) < 0.01 else nxt, Vector3.UP)

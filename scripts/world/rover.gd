class_name Rover
extends Node3D
## Six-wheeled exploration rover. AABB-vs-voxel physics, auto-climbs one-block steps,
## chase camera. Driven with the same control state as the player.

var world: VoxelWorld
var gravity := 9.0
var vel := Vector3.ZERO
var heading := 0.0
var on_ground := false
var driving := false
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.35
var wheels: Array[Node3D] = []
var body: Node3D
var _spin := 0.0
const HALF := 0.85
const HEIGHT := 1.3
const MAX_SPEED := 13.0


func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	var hull := Color("3b4358")
	var accent := Color("ffb02e")
	_box(body, Vector3(1.6, 0.45, 2.6), Vector3(0, 0.75, 0), hull)
	_box(body, Vector3(1.3, 0.55, 1.1), Vector3(0, 1.2, -0.25), Color("2a2f3c"))
	_box(body, Vector3(1.2, 0.35, 0.05), Vector3(0, 1.25, -0.82), Color("4fe3ff"), true)
	_box(body, Vector3(1.66, 0.1, 2.66), Vector3(0, 0.98, 0), accent)
	_box(body, Vector3(0.25, 0.12, 0.05), Vector3(-0.55, 0.8, -1.31), Color("fff3c4"), true)
	_box(body, Vector3(0.25, 0.12, 0.05), Vector3(0.55, 0.8, -1.31), Color("fff3c4"), true)
	_box(body, Vector3(0.08, 0.7, 0.08), Vector3(0.6, 1.7, 0.9), Color("5e6777"))
	_box(body, Vector3(0.18, 0.18, 0.18), Vector3(0.6, 2.05, 0.9), Color("ff5ad0"), true)
	for z in [-0.9, 0.0, 0.9]:
		for x in [-0.9, 0.9]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.42, z)
			add_child(w)
			_box(w, Vector3(0.3, 0.8, 0.8), Vector3.ZERO, Color("15161b"))
			_box(w, Vector3(0.32, 0.3, 0.3), Vector3.ZERO, Color("5e6777"))
			wheels.append(w)
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 260
	cam.top_level = true
	add_child(cam)


func _box(parent: Node3D, sz: Vector3, pos: Vector3, c: Color, glow := false) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c * 1.4
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


func drive(dt: float, ctl: Dictionary) -> void:
	var mv: Vector2 = ctl.move
	var look: Vector2 = ctl.look
	ctl.look = Vector2.ZERO
	cam_yaw -= look.x
	cam_pitch = clampf(cam_pitch - look.y, -1.2, 0.2)
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var speed := Vector2(vel.x, vel.z).dot(Vector2(fwd.x, fwd.z))
	heading -= mv.x * dt * (1.6 + absf(speed) * 0.05) * (1.0 if speed >= -0.5 else -1.0)
	var target := fwd * mv.y * MAX_SPEED * (1.4 if ctl.sprint else 1.0)
	var accel := 9.0 if on_ground else 1.5
	vel.x = move_toward(vel.x, target.x, accel * dt * 2.0)
	vel.z = move_toward(vel.z, target.z, accel * dt * 2.0)
	if mv.length() < 0.1 and on_ground:
		vel.x = move_toward(vel.x, 0, 8.0 * dt)
		vel.z = move_toward(vel.z, 0, 8.0 * dt)


func _process(dt: float) -> void:
	if world == null:
		return
	dt = minf(dt, 0.05)
	if not world.has_chunk_at(global_position):
		return
	vel.y = maxf(vel.y - gravity * dt, -40.0)
	var was := on_ground
	on_ground = false
	var bx := _move(0, vel.x * dt)
	var bz := _move(2, vel.z * dt)
	_move(1, vel.y * dt)
	if (bx or bz) and was:
		vel.y = sqrt(2.0 * gravity * 1.3)
	rotation.y = heading
	var hv := Vector2(vel.x, vel.z).length()
	_spin += hv * dt * 2.0
	for w in wheels:
		w.rotation.x = -_spin
	body.position.y = sin(Time.get_ticks_msec() * 0.02) * 0.02 * clampf(hv / 6.0, 0, 1)
	body.rotation.x = lerpf(body.rotation.x, clampf(vel.y * 0.03, -0.25, 0.25), dt * 5.0)
	if driving:
		var yaw := heading + cam_yaw
		var off := Vector3(sin(yaw), 0, cos(yaw)) * 7.5 * cos(cam_pitch) + Vector3(0, 2.0 - sin(cam_pitch) * 7.5, 0)
		cam.global_position = cam.global_position.lerp(global_position + off, minf(dt * 8.0, 1.0))
		cam.look_at(global_position + Vector3(0, 1.4, 0), Vector3.UP)


func _move(axis: int, d: float) -> bool:
	if d == 0.0:
		return false
	var p := global_position
	p[axis] += d
	for x in range(floori(p.x - HALF), floori(p.x + HALF - 0.0001) + 1):
		for y in range(floori(p.y), floori(p.y + HEIGHT - 0.0001) + 1):
			for z in range(floori(p.z - HALF), floori(p.z + HALF - 0.0001) + 1):
				if world.is_solid(x, y, z):
					if axis == 1:
						if d < 0:
							global_position.y = y + 1.0
							on_ground = true
						vel.y = 0.0
					elif axis == 0:
						vel.x *= -0.1
					else:
						vel.z *= -0.1
					return true
	global_position = p
	return false


func speed_kmh() -> int:
	return int(Vector2(vel.x, vel.z).length() * 3.6)

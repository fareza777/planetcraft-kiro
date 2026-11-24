class_name Player
extends Node3D
## First-person explorer. Collision is AABB vs voxel grid (no physics engine).
## Input comes from `ctl` (filled by touch or desktop controls each frame).

signal block_mined(pos: Vector3i, id: int)
signal block_placed(pos: Vector3i, id: int)
signal toast(text: String, color: Color)
signal died(reason: String)
signal use_requested

const HALF_W := 0.3
const HEIGHT := 1.8
const EYE := 1.62
const REACH := 6.0

var world: VoxelWorld
var inv := Inventory.new()
var stats := Survival.new()
var ctl := {"move": Vector2.ZERO, "look": Vector2.ZERO, "jump": false, "mine": false, "place": false, "hold_place": false, "sprint": false}
var build_rot := 0   # 0=N, 1=E, 2=S, 3=W
var blueprint: Array = []  # [{off: Vector3i, id: int}]
var vel := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var on_ground := false
var in_fluid := false
var head_in_fluid := false
var frozen := true
var gravity := 9.0
var selected := 0
var target: Dictionary = {}
var mine_progress := 0.0
var _mine_pos := Vector3i(0, -999, 0)
var _jet_time := 0.0
var _air_time := 0.0
var _fall_speed := 0.0
var _place_cd := 0.0
var _bob := 0.0
var jet_active := false
var xp := 0
var noclip := false
var fx: Fx
var sfx: Sfx
var combat: Creatures
var _shake := 0.0
var _recoil := 0.0
var _step_d := 0.0
var _dig_t := 0.0
var snap_to_surface := true
var hitstop_t := 0.0
var _sway := Vector2.ZERO
var _land_dip := 0.0
var _laser_heat := 0.0
var _heat_mat: StandardMaterial3D
var _emitter_ring: Node3D
var _jump_prev := false
var _jump_tap_t := 0.0
var _dash_cd := 0.0
var _dash_t := 0.0
var _base_fov := 72.0
var _fov_kick := 0.0
var speed_mult := 1.0
var dmg_mult := 1.0
var mine_mult := 1.0
var dash_cost_mult := 1.0

var cam: Camera3D
var hand: Node3D
var beam: MeshInstance3D
var outline: MeshInstance3D
var crack: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _crack_mat: StandardMaterial3D


func _ready() -> void:
	cam = Camera3D.new()
	cam.position = Vector3(0, EYE, 0)
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 260.0
	add_child(cam)
	_build_hand()
	_build_target_meshes()


var _held_id := "?"
var _held: Node3D
var _swing := 0.0


func _build_hand() -> void:
	hand = Node3D.new()
	hand.position = Vector3(0.32, -0.3, -0.55)
	cam.add_child(hand)
	_held = Node3D.new()
	hand.add_child(_held)
	_tool_root = Node3D.new()
	hand.add_child(_tool_root)
	_build_tool_model(_tool_root)
	_build_beam()


var _tool_root: Node3D


## First-person model for the selected hotbar item.
func _refresh_held() -> void:
	var s = inv.slots[selected]
	var id: String = s.id if s != null else ""
	if id == _held_id:
		return
	_held_id = id
	for c in _held.get_children():
		c.queue_free()
	var it := Reg.item(id)
	var t: String = it.get("type", "")
	var cols: Array = it.get("icon", {}).get("c", ["#5e6777", "#ffb02e", "#4fe3ff"])
	var c0 := Color.html(cols[0])
	var c1 := Color.html(cols[1 % cols.size()])
	var c2 := Color.html(cols[2 % cols.size()])
	_tool_root.visible = t == "" or t == "tool"
	match t:
		"block":
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.2, 0.2, 0.2)
			mi.mesh = bm
			var m := StandardMaterial3D.new()
			var bid: int = it.block
			m.albedo_texture = ImageTexture.create_from_image(Reg.tile_images[Reg.face_tiles[bid * 6 + 4]])
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if Reg.emissive[bid] == 1:
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if Reg.kind[bid] == Reg.Kind.CUTOUT or Reg.kind[bid] == Reg.Kind.PLANT:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mi.material_override = m
			mi.position = Vector3(-0.02, 0.02, -0.12)
			mi.rotation = Vector3(0.25, 0.6, 0.1)
			_held.add_child(mi)
		"weapon":
			var w: Dictionary = it.weapon
			if w.get("melee", false):
				_held.add_child(_box(Vector3(0.05, 0.05, 0.16), c0, Vector3(0, -0.02, 0.06)))
				_held.add_child(_box(Vector3(0.14, 0.03, 0.04), c0.lightened(0.2), Vector3(0, 0, -0.02)))
				_held.add_child(_box(Vector3(0.03, 0.06, 0.55), c1, Vector3(0, 0.0, -0.32), true))
				_held.add_child(_box(Vector3(0.012, 0.07, 0.56), c2, Vector3(0, 0.0, -0.32), true))
			else:
				var long: bool = it.icon.get("shape", "") == "rifle"
				var L := 0.5 if long else 0.3
				_held.add_child(_box(Vector3(0.1, 0.11, L), c0, Vector3(0, 0, -L * 0.3)))
				_held.add_child(_box(Vector3(0.105, 0.03, L * 0.8), c0.lightened(0.25), Vector3(0, 0.065, -L * 0.3)))
				_held.add_child(_box(Vector3(0.07, 0.15, 0.08), c0.darkened(0.35), Vector3(0, -0.12, 0.02), false, Vector3(-0.3, 0, 0)))
				_held.add_child(_box(Vector3(0.05, 0.05, 0.16), c0.darkened(0.2), Vector3(0, 0.0, -L * 0.8)))
				_held.add_child(_box(Vector3(0.06, 0.06, 0.03), c1, Vector3(0, 0.0, -L * 0.8 - 0.09), true))
				_held.add_child(_box(Vector3(0.11, 0.025, 0.12), c1, Vector3(0, 0.02, -L * 0.25), true))
				if long:
					_held.add_child(_box(Vector3(0.05, 0.05, 0.16), Color(0.15, 0.16, 0.2), Vector3(0, 0.11, -L * 0.3)))
					_held.add_child(_box(Vector3(0.035, 0.035, 0.01), c2, Vector3(0, 0.11, -L * 0.3 - 0.085), true))
		"tool", "":
			pass
		_:
			var sp := Sprite3D.new()
			sp.texture = Reg.icon(id)
			sp.pixel_size = 0.0075
			sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sp.shaded = false
			sp.position = Vector3(-0.04, 0.05, -0.1)
			sp.rotation = Vector3(0, 0.35, 0)
			_held.add_child(sp)
	UiAnim_hand_pop()


func UiAnim_hand_pop() -> void:
	hand.scale = Vector3.ONE * 0.6
	var tw := hand.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(hand, "scale", Vector3.ONE, 0.22)


## Suit sleeve + glove visible at the bottom right, wearing the equipped suit's fabric.
func _build_sleeve() -> void:
	var sd: Dictionary = Game.equipped_def("suit")
	var cols: Array = Game.cosmetic("suit")
	_sleeve = Node3D.new()
	hand.add_child(_sleeve)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.13, 0.13, 0.42)
	arm.mesh = am
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = SuitPreview.texture_for(sd)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	mat.roughness = 0.7
	arm.material_override = mat
	arm.position = Vector3(0.06, -0.1, 0.32)
	arm.rotation = Vector3(0.18, 0.0, 0.05)
	_sleeve.add_child(arm)
	_sleeve.add_child(_box(Vector3(0.15, 0.06, 0.06), cols[1], Vector3(0.06, -0.08, 0.12)))
	_sleeve.add_child(_box(Vector3(0.1, 0.11, 0.12), cols[1].darkened(0.25), Vector3(0.02, -0.06, 0.07)))
	_sleeve.add_child(_box(Vector3(0.04, 0.012, 0.05), cols[2], Vector3(0.06, -0.027, 0.2), true))


func _build_tool_model(root: Node3D) -> void:
	var suit: Array = Game.cosmetic("suit")
	_build_sleeve()
	# Main chassis & bevelled upper receiver
	root.add_child(_box(Vector3(0.11, 0.10, 0.42), suit[0], Vector3.ZERO))
	root.add_child(_box(Vector3(0.085, 0.04, 0.34), suit[0].lightened(0.18), Vector3(0, 0.062, -0.02)))
	root.add_child(_box(Vector3(0.13, 0.045, 0.18), suit[1], Vector3(0, 0.055, 0.07)))
	# Side armoured rails + energy core cell
	root.add_child(_box(Vector3(0.022, 0.06, 0.28), suit[1].darkened(0.2), Vector3(-0.062, 0.0, -0.04)))
	root.add_child(_box(Vector3(0.022, 0.06, 0.28), suit[1].darkened(0.2), Vector3(0.062, 0.0, -0.04)))
	root.add_child(_box(Vector3(0.128, 0.024, 0.13), suit[2], Vector3(0, 0.01, -0.03), true))
	root.add_child(_box(Vector3(0.115, 0.018, 0.30), suit[2], Vector3(0, -0.058, -0.02), true))
	# Ergonomic grip & rear battery cap
	root.add_child(_box(Vector3(0.075, 0.16, 0.08), Color("2a2f3c"), Vector3(0, -0.11, 0.12), false, Vector3(-0.22, 0, 0)))
	root.add_child(_box(Vector3(0.09, 0.08, 0.05), suit[1].darkened(0.35), Vector3(0, 0.0, 0.22)))
	# Heat-sink cooling fins that glow hotter while mining
	_heat_mat = StandardMaterial3D.new()
	_heat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_heat_mat.albedo_color = Color(0.25, 0.28, 0.34)
	for k in 3:
		var fin := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.122, 0.018, 0.028)
		fin.mesh = fm
		fin.material_override = _heat_mat
		fin.position = Vector3(0, 0.045, -0.11 - k * 0.055)
		fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fin)
	# Emitter barrel & rotating focusing prongs
	root.add_child(_box(Vector3(0.055, 0.055, 0.12), suit[2], Vector3(0, 0.0, -0.26), true))
	_emitter_ring = Node3D.new()
	_emitter_ring.position = Vector3(0, 0, -0.32)
	root.add_child(_emitter_ring)
	for k in 3:
		var a := k * TAU / 3.0
		_emitter_ring.add_child(_box(Vector3(0.02, 0.02, 0.07), suit[1].darkened(0.25), Vector3(cos(a) * 0.038, sin(a) * 0.038, 0)))


var _beam_glow: MeshInstance3D
var _beam_glow_mat: StandardMaterial3D
var _impact: MeshInstance3D
var _impact_mat: StandardMaterial3D
var _impact_t := 0.0
var _jet_fx: CPUParticles3D
var _sleeve: Node3D
var _laser_style := "pulse"


func _build_beam() -> void:
	var laser: Dictionary = Game.equipped_def("laser")
	_laser_style = laser.get("style", "pulse")
	# bright core
	beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.018, 1.0)
	beam.mesh = bm
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.4, 1.4, 1.4)
	beam.material_override = _beam_mat
	beam.visible = false
	add_child(beam)
	# coloured outer glow (child, so it follows the core)
	_beam_glow = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.07, 0.07, 1.0)
	_beam_glow.mesh = gm
	_beam_glow_mat = StandardMaterial3D.new()
	_beam_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_glow.material_override = _beam_glow_mat
	beam.add_child(_beam_glow)
	# impact flare at the hit point
	_impact = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 8
	sm.rings = 4
	_impact.mesh = sm
	_impact_mat = StandardMaterial3D.new()
	_impact_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_impact_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_impact.material_override = _impact_mat
	_impact.top_level = true
	_impact.visible = false
	add_child(_impact)
	# jetpack trail in the suit's thruster colour
	var trail := Color.html(Game.equipped_def("suit").get("trail", "#ffb02e"))
	_jet_fx = CPUParticles3D.new()
	_jet_fx.amount = 36
	_jet_fx.lifetime = 0.5
	_jet_fx.local_coords = false
	_jet_fx.direction = Vector3.DOWN
	_jet_fx.spread = 18.0
	_jet_fx.initial_velocity_min = 3.0
	_jet_fx.initial_velocity_max = 5.0
	_jet_fx.gravity = Vector3.ZERO
	_jet_fx.scale_amount_min = 0.6
	_jet_fx.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	_jet_fx.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.add_point(0.25, Color(trail.r, trail.g, trail.b, 0.8))
	grad.set_color(grad.get_point_count() - 1, Color(trail.r * 0.4, trail.g * 0.4, trail.b * 0.4, 0.0))
	_jet_fx.color_ramp = grad
	_jet_fx.position = Vector3(0, 0.9, 0.35)
	_jet_fx.emitting = false
	add_child(_jet_fx)


func _box(size: Vector3, color: Color, pos: Vector3, glow := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color * 1.4
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_target_meshes() -> void:
	var im := ArrayMesh.new()
	var pts := PackedVector3Array()
	var c := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]
	for e in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
		pts.append((c[e[0]] - Vector3(0.5, 0.5, 0.5)) * 1.01 + Vector3(0.5, 0.5, 0.5))
		pts.append((c[e[1]] - Vector3(0.5, 0.5, 0.5)) * 1.01 + Vector3(0.5, 0.5, 0.5))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	im.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	outline = MeshInstance3D.new()
	outline.mesh = im
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.albedo_color = Color(0.85, 1.0, 1.0)
	outline.material_override = om
	outline.top_level = true
	outline.visible = false
	add_child(outline)
	crack = MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(1.02, 1.02, 1.02)
	crack.mesh = cb
	_crack_mat = StandardMaterial3D.new()
	_crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crack_mat.albedo_color = Color(1, 1, 1, 0)
	var tf = load("res://scripts/voxel/texture_factory.gd")
	_crack_mat.albedo_texture = ImageTexture.create_from_image(tf.make_crack(7))
	_crack_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	crack.material_override = _crack_mat
	crack.top_level = true
	crack.visible = false
	add_child(crack)


# ------------------------------------------------------------------ frame

func eye_pos() -> Vector3:
	return global_position + Vector3(0, EYE, 0)


func look_dir() -> Vector3:
	return -cam.global_transform.basis.z


func trigger_hitstop(sec: float) -> void:
	if not Game.settings.get("camera_shake", true):
		return
	hitstop_t = maxf(hitstop_t, clampf(sec, 0.0, 0.065))


func dash_ready() -> bool:
	return _dash_cd <= 0.0 and stats.energy >= 8.0 * dash_cost_mult


func is_dashing() -> bool:
	return _dash_t > 0.0


func _process(dt: float) -> void:
	if world == null:
		return
	dt = minf(dt, 0.05)
	var look: Vector2 = ctl.look
	ctl.look = Vector2.ZERO
	yaw -= look.x
	pitch = clampf(pitch - look.y, -1.52, 1.52)
	_sway.x = clampf(_sway.x - look.x * 0.22, -0.075, 0.075)
	_sway.y = clampf(_sway.y + look.y * 0.22, -0.065, 0.065)
	rotation = Vector3(0, yaw, 0)
	cam.rotation = Vector3(pitch, 0, 0)
	if frozen:
		if world.has_chunk_at(global_position) and world.loaded_ratio() > 0.3:
			var top := world.column_top(floori(global_position.x), floori(global_position.z))
			if top > 0:
				if snap_to_surface and global_position.y < top + 1:
					global_position.y = top + 1.02
				frozen = false
				snap_to_surface = false
		return
	if hitstop_t > 0.0:
		hitstop_t = maxf(0.0, hitstop_t - dt)
		return
	var was_ground := on_ground
	var fall_v := vel.y
	_physics(dt)
	_update_target()
	_update_mining(dt)
	_update_place(dt)
	_update_hand(dt)
	_update_feel(dt, was_ground, fall_v)


func shake(a: float) -> void:
	if not Game.settings.get("camera_shake", true):
		return
	_shake = maxf(_shake, a)


func recoil(a: float) -> void:
	_recoil = minf(_recoil + a, 0.3)


func _ground_color() -> Color:
	var bid := world.get_block(floori(global_position.x), floori(global_position.y - 0.2), floori(global_position.z))
	return Reg.block_color(bid) if bid > 0 else Color(0.55, 0.55, 0.6)


func _update_feel(dt: float, was_ground: bool, fall_v: float) -> void:
	_shake = maxf(0.0, _shake - dt * 1.8)
	_recoil = move_toward(_recoil, 0.0, dt * 1.2)
	_fov_kick = move_toward(_fov_kick, 0.0, dt * 24.0)
	_land_dip = move_toward(_land_dip, 0.0, dt * 3.5)
	_base_fov = float(Game.settings.get("fov", 72))
	var sprint_fov := 3.5 if (ctl.sprint and Vector2(vel.x, vel.z).length() > 4.5) else 0.0
	cam.fov = lerpf(cam.fov, _base_fov + sprint_fov + _fov_kick, minf(dt * 12.0, 1.0))
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * _shake * 0.25
	cam.position = Vector3(0, EYE - _land_dip * 0.14, 0) + off
	cam.rotation = Vector3(pitch + _recoil, 0, sin(Time.get_ticks_msec() * 0.03) * _shake * 0.03)
	var hv := Vector2(vel.x, vel.z).length()
	if on_ground and hv > 0.5:
		_step_d += hv * dt
		if _step_d > 2.1:
			_step_d = 0.0
			if sfx != null:
				sfx.play("step", -14.0, 1.0, 0.2)
			if fx != null and not in_fluid:
				fx.dust_step(global_position, _ground_color())
	if not was_ground and on_ground and fall_v < -4.2:
		var strength := clampf((-fall_v - 4.0) / 10.0, 0.2, 1.5)
		_land_dip = minf(1.0, strength * 0.85)
		if sfx != null:
			sfx.play("land", -6.0)
		if fx != null and not in_fluid:
			fx.land_puff(global_position, _ground_color(), strength)
		if fall_v < -11.0:
			shake(0.3)
	if was_ground and not on_ground and vel.y > 3.0 and sfx != null:
		sfx.play("jump", -12.0)
	if sfx != null:
		sfx.loop("jet", jet_active, -12.0, 1.0, dt)
		sfx.loop("laser", beam.visible, -14.0, 1.0 + mine_progress * 0.3, dt)


func _physics(dt: float) -> void:
	var feet := global_position
	var fid := world.get_block(floori(feet.x), floori(feet.y + 0.2), floori(feet.z))
	var hid := world.get_block(floori(feet.x), floori(feet.y + EYE), floori(feet.z))
	in_fluid = fid > 0 and Reg.kind[fid] == Reg.Kind.FLUID
	head_in_fluid = hid > 0 and Reg.kind[hid] == Reg.Kind.FLUID
	var mv: Vector2 = ctl.move
	if mv.length() > 1.0:
		mv = mv.normalized()
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var speed := 4.4 * speed_mult
	if ctl.sprint and on_ground:
		speed = 6.6 * speed_mult
	elif ctl.sprint:
		speed = 6.0 * speed_mult
	if in_fluid:
		speed = 2.6 * speed_mult
	_dash_cd = maxf(0.0, _dash_cd - dt)
	_dash_t = maxf(0.0, _dash_t - dt)
	_jump_tap_t = maxf(0.0, _jump_tap_t - dt)
	var jump_edge: bool = ctl.jump and not _jump_prev
	_jump_prev = ctl.jump
	# Double-tap JUMP triggers a directional jetpack dash (dodge burst)
	if jump_edge and not in_fluid and not noclip:
		if _jump_tap_t > 0.0 and dash_ready():
			var ddir := fwd * mv.y + right * mv.x
			if ddir.length() < 0.1:
				ddir = fwd
			ddir = ddir.normalized()
			var dash_spd := 14.5 if stats.upgrades.has("jet") else 12.5
			vel.x = ddir.x * dash_spd
			vel.z = ddir.z * dash_spd
			vel.y = maxf(vel.y, 2.4)
			stats.energy = maxf(0.0, stats.energy - 8.0 * dash_cost_mult)
			_dash_cd = 1.05
			_dash_t = 0.22
			_jump_tap_t = 0.0
			_fov_kick = 8.0
			shake(0.14)
			Platform.vibrate(18)
			if sfx != null:
				sfx.play("jet", -3.0, 1.55)
			if fx != null:
				fx.dash_burst(global_position + Vector3(0, 0.9, 0), Color.html(Game.equipped_def("suit").get("trail", "#ffb02e")))
		else:
			_jump_tap_t = 0.28
	var wish := (fwd * mv.y + right * mv.x) * speed
	var accel := (16.0 if on_ground else 5.0) if _dash_t <= 0.0 else 1.2
	vel.x = move_toward(vel.x, wish.x, accel * speed * dt)
	vel.z = move_toward(vel.z, wish.z, accel * speed * dt)
	jet_active = false
	if noclip:
		vel.y = (6.0 if ctl.jump else 0.0) - (6.0 if ctl.sprint else 0.0)
	elif in_fluid:
		vel.y = move_toward(vel.y, 3.0 if ctl.jump else -1.6, 12.0 * dt)
	else:
		if ctl.jump and on_ground:
			vel.y = sqrt(2.0 * gravity * 1.3)
			on_ground = false
			_jet_time = 0.0
		elif ctl.jump and not on_ground:
			_jet_time += dt
			if _jet_time > 0.22 and stats.energy > 0.5:
				jet_active = true
				var thrust := gravity + (11.0 if stats.upgrades.has("jet") else 7.0)
				vel.y = minf(vel.y + thrust * dt, 7.5 if stats.upgrades.has("jet") else 5.0)
				stats.energy = maxf(0.0, stats.energy - (6.0 if stats.upgrades.has("jet") else 9.0) * dt)
		else:
			_jet_time = 0.0
		vel.y = maxf(vel.y - gravity * dt, -55.0)
	var was_ground := on_ground
	var fall := -vel.y
	on_ground = false
	var blocked_h := false
	blocked_h = _move_axis(0, vel.x * dt) or blocked_h
	blocked_h = _move_axis(2, vel.z * dt) or blocked_h
	_move_axis(1, vel.y * dt)
	if on_ground and not was_ground and fall > 13.0 and not in_fluid:
		var dmg := (fall - 13.0) * 4.0 * (gravity / 9.0)
		stats.damage(dmg, "impact")
	if blocked_h and was_ground and mv.length() > 0.3 and not in_fluid and Game.settings.get("auto_jump", true):
		# auto-step up one block when walking into a ledge
		var ahead := global_position + wish.normalized() * (HALF_W + 0.35)
		var bx := floori(ahead.x)
		var bz := floori(ahead.z)
		var by := floori(global_position.y + 0.1)
		if world.is_solid(bx, by, bz) and not world.is_solid(bx, by + 1, bz) and not world.is_solid(bx, by + 2, bz) and not world.is_solid(floori(global_position.x), by + 2, floori(global_position.z)):
			vel.y = sqrt(2.0 * gravity * 1.15)
	if global_position.y < -40.0:
		stats.damage(1000.0, "the void")


func _move_axis(axis: int, d: float) -> bool:
	if d == 0.0:
		return false
	if noclip:
		var p := global_position
		p[axis] += d
		global_position = p
		return false
	var hit := false
	var steps := int(ceil(absf(d) / 0.45))
	var sd := d / steps
	for s in steps:
		var p := global_position
		p[axis] += sd
		var mn := Vector3(p.x - HALF_W, p.y, p.z - HALF_W)
		var mx := Vector3(p.x + HALF_W, p.y + HEIGHT, p.z + HALF_W)
		var collided := false
		for x in range(floori(mn.x), floori(mx.x - 0.0001) + 1):
			for y in range(floori(mn.y), floori(mx.y - 0.0001) + 1):
				for z in range(floori(mn.z), floori(mx.z - 0.0001) + 1):
					if world.is_solid(x, y, z):
						collided = true
						if axis == 0:
							p.x = (x - HALF_W - 0.001) if sd > 0 else (x + 1 + HALF_W + 0.001)
						elif axis == 2:
							p.z = (z - HALF_W - 0.001) if sd > 0 else (z + 1 + HALF_W + 0.001)
						else:
							p.y = (y - HEIGHT - 0.001) if sd > 0 else (y + 1.0)
		global_position = p
		if collided:
			hit = true
			if axis == 1:
				if sd < 0:
					on_ground = true
				vel.y = 0.0
			elif axis == 0:
				vel.x = 0.0
			else:
				vel.z = 0.0
			break
	return hit


# ------------------------------------------------------------------ interaction

func selected_item() -> Dictionary:
	var s = inv.slots[selected]
	if s == null:
		return {}
	return Reg.item(s.id)


func tool_stats() -> Dictionary:
	var best := {"tier": 0, "speed": 0.45, "dmg": 2}
	for s in inv.slots:
		if s != null:
			var it := Reg.item(s.id)
			if it.get("type", "") == "tool" and int(it.tool.tier) > int(best.tier):
				best = it.tool
	return best


func _update_target() -> void:
	target = world.raycast(eye_pos(), look_dir(), REACH)
	if target.is_empty():
		outline.visible = false
		crack.visible = false
		return
	var p: Vector3i = target.pos
	outline.visible = true
	outline.global_position = Vector3(p)


func _update_mining(dt: float) -> void:
	beam.visible = false
	if not ctl.mine:
		mine_progress = 0.0
		crack.visible = false
		return
	var it := selected_item()
	if it.get("type", "") == "weapon":
		if combat != null:
			combat.fire_weapon(it)
		crack.visible = false
		return
	if combat != null:
		var c := combat.laser_tick(dt, float(tool_stats().get("dmg", 2)))
		if c != null:
			_beam_to(c.center())
			mine_progress = 0.0
			crack.visible = false
			return
	if target.is_empty():
		mine_progress = 0.0
		crack.visible = false
		return
	var p: Vector3i = target.pos
	if p != _mine_pos:
		_mine_pos = p
		mine_progress = 0.0
	var id: int = target.id
	var hard := Reg.hardness[id]
	var tool := tool_stats()
	_show_beam(p)
	if hard < 0.0:
		_toast_once("Too hard to mine", Color(1, 0.5, 0.4))
		return
	if Reg.tier[id] > int(tool.tier):
		_toast_once("Needs a tier %d tool" % Reg.tier[id], Color(1, 0.6, 0.3))
		return
	if stats.energy <= 0.0 and hard > 0.3:
		_toast_once("Suit energy depleted", Color(1, 0.6, 0.3))
		return
	stats.energy = maxf(0.0, stats.energy - 0.6 * dt)
	mine_progress += dt * float(tool.speed) * mine_mult / maxf(hard, 0.05)
	_dig_t -= dt
	if _dig_t <= 0.0:
		_dig_t = 0.16
		if sfx != null:
			sfx.play("dig", -12.0, 0.8 + 0.4 / maxf(hard, 0.3))
		if fx != null:
			var hit_pt := Vector3(p) + Vector3(0.5, 0.5, 0.5) + Vector3(target.normal) * 0.52
			fx.chips(hit_pt, Reg.block_color(id))
			fx.sparks(hit_pt, Game.cosmetic("laser")[0], 4)
	crack.visible = true
	crack.global_position = Vector3(p) + Vector3(0.5, 0.5, 0.5)
	_crack_mat.albedo_color = Color(1, 1, 1, clampf(mine_progress * 1.3, 0.0, 0.9))
	crack.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.05) * 0.012 * mine_progress)
	if mine_progress >= 1.0:
		mine_progress = 0.0
		if world.set_block(p.x, p.y, p.z, 0):
			var drop := Reg.block_drop(id)
			if drop != "":
				var left := inv.add(drop, 1)
				if left > 0:
					toast.emit("Inventory full", Color(1, 0.5, 0.4))
			xp += int(Reg.block_def(id).get("xp", 0))
			if fx != null:
				fx.block_debris(p, id)
			if sfx != null:
				sfx.play("break_crystal" if Reg.emissive[id] == 1 and Reg.kind[id] == Reg.Kind.CUTOUT else "break", -6.0)
			shake(0.06 if hard < 1.4 else 0.12)
			if hard >= 1.4:
				trigger_hitstop(0.042)
			Platform.vibrate(12 if hard < 1.4 else 22)
			block_mined.emit(p, id)
			# plants on top fall with the block
			var above := world.get_block(p.x, p.y + 1, p.z)
			if above > 0 and Reg.kind[above] == Reg.Kind.PLANT:
				world.set_block(p.x, p.y + 1, p.z, 0)
				var d2 := Reg.block_drop(above)
				if d2 != "":
					inv.add(d2, 1)


var _last_toast := ""
var _toast_t := 0


func _toast_once(t: String, c: Color) -> void:
	var now := Time.get_ticks_msec()
	if t != _last_toast or now - _toast_t > 2500:
		_last_toast = t
		_toast_t = now
		toast.emit(t, c)


func _show_beam(p: Vector3i) -> void:
	_beam_to(Vector3(p) + Vector3(0.5, 0.5, 0.5))


func _beam_to(to: Vector3) -> void:
	# beam leaves the mining tool's emitter, not whatever item is in the hand
	var from := _tool_root.global_position + -cam.global_transform.basis.z * 0.32
	var mid := (from + to) * 0.5
	var len := from.distance_to(to)
	var t := Time.get_ticks_msec() / 1000.0
	beam.visible = true
	beam.global_position = mid
	beam.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var col: Color = Game.cosmetic("laser")[0]
	var w := 1.0
	match _laser_style:
		"helix":
			w = 1.0 + 0.5 * sin(t * 40.0)
			beam.rotation.z = t * 12.0
		"crackle":
			w = 0.6 + randf() * 1.4
		"void":
			w = 1.5 + 0.3 * sin(t * 8.0)
			col = col.darkened(0.2)
		"solar":
			w = 1.3 + 0.4 * sin(t * 25.0)
		_:
			w = 1.0 + randf() * 0.4
	beam.scale = Vector3(w, w, len)
	_beam_glow_mat.albedo_color = Color(col.r, col.g, col.b, 0.45 + 0.15 * sin(t * 30.0))
	_impact.visible = true
	_impact.global_position = to - (to - from).normalized() * 0.45
	var pulse := 0.8 + 0.4 * sin(t * 35.0)
	_impact.scale = Vector3.ONE * pulse * (1.6 if _laser_style == "void" else 1.0)
	_impact_mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
	_impact_t -= get_process_delta_time()
	if _impact_t <= 0.0 and fx != null:
		_impact_t = 0.09
		fx.sparks(_impact.global_position, col, 3)


func _update_place(dt: float) -> void:
	_place_cd -= dt
	if not ctl.place and not ctl.get("hold_place", false):
		return
	var was_tap: bool = ctl.place
	ctl.place = false
	if _place_cd > 0.0:
		return
	_place_cd = 0.19 if was_tap else 0.22
	if was_tap:
		use_requested.emit()
	elif selected_item().get("type", "") == "block":
		use_selected()


func rotate_build() -> String:
	build_rot = posmod(build_rot + 1, 4)
	return ["North", "East", "South", "West"][build_rot]


func copy_blueprint() -> int:
	if target.is_empty():
		toast.emit("Aim at a structure to copy a 3×3×3 blueprint", Color(1, 0.8, 0.3))
		return 0
	var c: Vector3i = target.pos
	blueprint.clear()
	for dy in range(0, 3):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var id := world.get_block(c.x + dx, c.y + dy, c.z + dz)
				if id > 0 and Reg.block_def(id).get("place", true):
					blueprint.append({"off": Vector3i(dx, dy, dz), "id": id})
	toast.emit("Blueprint copied (%d blocks). Press V to paste." % blueprint.size(), Color(0.35, 0.92, 1.0))
	return blueprint.size()


func paste_blueprint() -> int:
	if blueprint.is_empty():
		toast.emit("No blueprint copied yet (aim & press B to copy)", Color(1, 0.8, 0.3))
		return 0
	if target.is_empty():
		return 0
	var origin: Vector3i = target.pos + target.normal
	var placed := 0
	for entry in blueprint:
		var o: Vector3i = entry.off
		var r := o
		match build_rot:
			1: r = Vector3i(-o.z, o.y, o.x)
			2: r = Vector3i(-o.x, o.y, -o.z)
			3: r = Vector3i(o.z, o.y, -o.x)
		var dest := origin + r
		var bid: int = entry.id
		var item_name: String = Reg.block_def(bid).name
		if inv.count(item_name) <= 0:
			continue
		var cur := world.get_block(dest.x, dest.y, dest.z)
		if cur != 0 and Reg.kind[cur] != Reg.Kind.FLUID and Reg.kind[cur] != Reg.Kind.PLANT:
			continue
		if Reg.solid[bid] == 1 and _overlaps_player(dest):
			continue
		if world.set_block(dest.x, dest.y, dest.z, bid):
			inv.remove(item_name, 1)
			block_placed.emit(dest, bid)
			placed += 1
	if placed > 0:
		if sfx != null:
			sfx.play("place", -4.0)
		toast.emit("Blueprint pasted (%d blocks)" % placed, Color(0.45, 1.0, 0.6))
	else:
		toast.emit("Need matching blocks in inventory to paste blueprint", Color(1, 0.6, 0.3))
	return placed


## Uses the selected hotbar item: place a block, eat/drink, or interact.
func use_selected() -> void:
	var s = inv.slots[selected]
	if s == null:
		return
	var it := Reg.item(s.id)
	match it.get("type", ""):
		"block":
			if target.is_empty():
				return
			var p: Vector3i = target.pos
			var tid: int = target.id
			var dest: Vector3i = p
			if Reg.kind[tid] != Reg.Kind.PLANT:
				dest = p + target.normal
			var cur := world.get_block(dest.x, dest.y, dest.z)
			if cur < 0 or (cur != 0 and Reg.kind[cur] != Reg.Kind.FLUID and Reg.kind[cur] != Reg.Kind.PLANT):
				return
			var bid: int = it.block
			if Reg.solid[bid] == 1 and _overlaps_player(dest):
				return
			if world.set_block(dest.x, dest.y, dest.z, bid):
				inv.remove_at(selected, 1)
				if sfx != null:
					sfx.play("place", -6.0)
				block_placed.emit(dest, bid)
		"food", "consumable":
			if it.get("lure", false):
				if combat != null and combat.try_tame():
					inv.remove_at(selected, 1)
					toast.emit("Creature tamed! It will follow and defend you.", Color(0.5, 1, 0.6))
				else:
					toast.emit("Aim at a tameable creature (e.g. Mossback)", Color(1, 0.8, 0.4))
				return
			if stats.consume(it):
				inv.remove_at(selected, 1)
				toast.emit("Used " + it.label, Color(0.6, 1, 0.7))


func _overlaps_player(b: Vector3i) -> bool:
	var p := global_position
	return b.x + 1 > p.x - HALF_W and b.x < p.x + HALF_W and b.z + 1 > p.z - HALF_W and b.z < p.z + HALF_W and b.y + 1 > p.y and b.y < p.y + HEIGHT


func swing() -> void:
	_swing = 1.0


func _update_hand(dt: float) -> void:
	_refresh_held()
	# while mining with a non-weapon in hand, show the mining tool instead of the held item
	var weapon: bool = selected_item().get("type", "") == "weapon"
	var mining_now: bool = ctl.mine and not weapon
	_tool_root.visible = mining_now or _held.get_child_count() == 0
	_held.visible = not mining_now
	if not beam.visible:
		_impact.visible = false
	_jet_fx.emitting = jet_active or _dash_t > 0.0
	_swing = maxf(0.0, _swing - dt * 4.0)
	_sway = _sway.lerp(Vector2.ZERO, minf(dt * 10.0, 1.0))
	# Laser heat buildup while firing beam -> fins glow warm orange-red and emitter spins
	_laser_heat = clampf(_laser_heat + (dt * 0.85 if beam.visible else -dt * 0.55), 0.0, 1.0)
	if _heat_mat != null:
		var cool := Color(0.25, 0.28, 0.34)
		var hot := Color(1.7, 0.55, 0.15)
		_heat_mat.albedo_color = cool.lerp(hot, _laser_heat * _laser_heat)
	if _emitter_ring != null:
		_emitter_ring.rotation.z += dt * (2.0 + _laser_heat * 18.0) if (beam.visible or _laser_heat > 0.05) else 0.0
	var right_v := Vector3(cos(yaw), 0, -sin(yaw))
	var strafe := clampf(vel.dot(right_v) * 0.012, -0.08, 0.08)
	hand.rotation = Vector3(-sin(_swing * PI) * 0.9 - _sway.y * 1.4 + _recoil * 0.8, sin(_swing * PI) * 0.5 + _sway.x * 1.6, -strafe)
	var moving: bool = Vector2(vel.x, vel.z).length() > 0.5 and on_ground
	if moving:
		_bob += dt * (11.0 if ctl.sprint else 9.0)
	var bob := Vector3(cos(_bob) * 0.012, absf(sin(_bob)) * 0.018, 0) if moving else Vector3.ZERO
	var kick := Vector3(0, 0, 0.03 * sin(Time.get_ticks_msec() * 0.06)) if beam.visible else Vector3.ZERO
	var sway_off := Vector3(_sway.x * 0.45, -_sway.y * 0.35 - _land_dip * 0.05, _recoil * 0.18)
	hand.position = Vector3(0.32, -0.3, -0.55) + bob + kick + sway_off


func apply_modules() -> void:
	var m := stats.recalc_caps()
	speed_mult = float(m.speed)
	dmg_mult = float(m.dmg)
	mine_mult = float(m.mine)
	dash_cost_mult = float(m.dash)


func respawn(pos: Vector3) -> void:
	global_position = pos
	vel = Vector3.ZERO
	stats.reset()
	frozen = true
	snap_to_surface = true

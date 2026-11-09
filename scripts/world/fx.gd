class_name Fx
extends Node3D
## Pooled visual effects: block debris, sparks, explosions, floating damage numbers,
## ambient particles around the player and weather.

const POOL := 10
const NUMBERS := 12

var _bursts: Array[CPUParticles3D] = []
var _next := 0
var _labels: Array[Label3D] = []
var _label_t: Array[float] = []
var _next_label := 0
var ambient: CPUParticles3D
var weather: CPUParticles3D
var _cube_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D


func _ready() -> void:
	_cube_mat = StandardMaterial3D.new()
	_cube_mat.vertex_color_use_as_albedo = true
	_cube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in POOL:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.local_coords = false
		var m := BoxMesh.new()
		m.size = Vector3(0.12, 0.12, 0.12)
		m.material = _cube_mat
		p.mesh = m
		add_child(p)
		_bursts.append(p)
	for i in NUMBERS:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 64
		l.outline_size = 12
		l.pixel_size = 0.006
		l.visible = false
		add_child(l)
		_labels.append(l)
		_label_t.append(0.0)


func _burst(pos: Vector3, color: Color, amount: int, speed: float, grav: float, life: float, size: float, glow := false) -> void:
	var p := _bursts[_next]
	_next = (_next + 1) % POOL
	p.global_position = pos
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	p.color = color
	var grad := Gradient.new()
	grad.set_color(0, color.lightened(0.15))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0) if glow else color.darkened(0.3))
	p.color_ramp = grad
	(p.mesh as BoxMesh).material = _glow_mat if glow else _cube_mat
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35, 0.35, 0.35)
	p.restart()
	p.emitting = true


func debris(block_pos: Vector3i, color: Color) -> void:
	_burst(Vector3(block_pos) + Vector3(0.5, 0.5, 0.5), color, 18, 4.5, 14.0, 0.9, 1.0)


func chips(pos: Vector3, color: Color) -> void:
	_burst(pos, color, 4, 2.5, 12.0, 0.35, 0.6)


func sparks(pos: Vector3, color: Color, n := 14) -> void:
	_burst(pos, color, n, 6.0, 4.0, 0.45, 0.7, true)


func explosion(pos: Vector3, color := Color(1.0, 0.6, 0.2)) -> void:
	_burst(pos, color, 40, 9.0, 3.0, 0.8, 2.0, true)
	_burst(pos, Color(0.25, 0.22, 0.25), 24, 5.0, 6.0, 1.2, 2.2)


func number(pos: Vector3, text: String, color: Color) -> void:
	var l := _labels[_next_label]
	_label_t[_next_label] = 0.9
	_next_label = (_next_label + 1) % NUMBERS
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
	l.visible = true


func setup_ambient(planet: Dictionary) -> void:
	ambient = CPUParticles3D.new()
	ambient.amount = 70
	ambient.lifetime = 6.0
	ambient.preprocess = 6.0
	ambient.local_coords = false
	ambient.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ambient.emission_box_extents = Vector3(18, 7, 18)
	ambient.direction = Vector3(0, 1, 0)
	ambient.spread = 180.0
	ambient.gravity = Vector3(0.2, 0.05, 0.1)
	ambient.initial_velocity_min = 0.1
	ambient.initial_velocity_max = 0.5
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = _glow_mat
	ambient.mesh = q
	var c := Color.html(planet.get("color", "#4fe3ff")).lightened(0.4)
	var grad := Gradient.new()
	grad.set_color(0, Color(c.r, c.g, c.b, 0.0))
	grad.add_point(0.3, Color(c.r, c.g, c.b, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(c.r, c.g, c.b, 0.0))
	ambient.color_ramp = grad
	add_child(ambient)
	weather = CPUParticles3D.new()
	weather.amount = 260
	weather.lifetime = 1.6
	weather.local_coords = false
	weather.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	weather.emission_box_extents = Vector3(16, 1, 16)
	weather.direction = Vector3(0, -1, 0)
	weather.spread = 8.0
	weather.gravity = Vector3(0, -6, 0)
	weather.initial_velocity_min = 10.0
	weather.initial_velocity_max = 14.0
	var wq := QuadMesh.new()
	wq.size = Vector2(0.04, 0.5)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	wm.vertex_color_use_as_albedo = true
	wq.material = wm
	weather.mesh = wq
	weather.emitting = false
	add_child(weather)


func set_weather(kind: String, color: Color) -> void:
	if weather == null:
		return
	weather.emitting = kind != "clear" and kind != "meteor_shower" and kind != "gravity_anomaly"
	weather.color = Color(color.r, color.g, color.b, 0.55)
	match kind:
		"snow", "blizzard":
			weather.initial_velocity_min = 1.5
			weather.initial_velocity_max = 3.0
			weather.gravity = Vector3(3.0 if kind == "blizzard" else 0.5, -2.0, 1.0)
			(weather.mesh as QuadMesh).size = Vector2(0.08, 0.08)
			weather.lifetime = 4.0
		"dust_storm", "ash_storm":
			weather.initial_velocity_min = 8.0
			weather.initial_velocity_max = 12.0
			weather.direction = Vector3(1, -0.1, 0.3)
			weather.gravity = Vector3(4, 0, 1)
			(weather.mesh as QuadMesh).size = Vector2(0.06, 0.06)
			weather.lifetime = 2.0
		_:
			weather.direction = Vector3(0, -1, 0)
			weather.initial_velocity_min = 10.0
			weather.initial_velocity_max = 14.0
			weather.gravity = Vector3(0, -6, 0)
			(weather.mesh as QuadMesh).size = Vector2(0.04, 0.5)
			weather.lifetime = 1.6


func follow(pos: Vector3, night: bool) -> void:
	if ambient != null:
		ambient.global_position = pos
		ambient.emitting = night
	if weather != null:
		weather.global_position = pos + Vector3(0, 12, 0)


func _process(dt: float) -> void:
	for i in NUMBERS:
		if _label_t[i] > 0.0:
			_label_t[i] -= dt
			var l := _labels[i]
			l.global_position.y += dt * 1.4
			l.modulate.a = clampf(_label_t[i] * 2.0, 0.0, 1.0)
			if _label_t[i] <= 0.0:
				l.visible = false

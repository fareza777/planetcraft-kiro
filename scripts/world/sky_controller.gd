class_name SkyController
extends Node
## Day/night cycle, sky shader, fog and terrain light uniforms for the current planet.

var planet: Dictionary
var env := Environment.new()
var world_env := WorldEnvironment.new()
var sun := DirectionalLight3D.new()
var sky_mat := ShaderMaterial.new()
var materials: Array = []
var time_of_day := 0.32
var day_length := 720.0
var daylight := 1.0
var sun_dir := Vector3.UP
var storm := 0.0
var storm_color := Color(0.5, 0.4, 0.3)
var view_dist := 96.0
var _c := {}


func setup(p: Dictionary, mats: Array, glow: bool) -> void:
	planet = p
	materials = mats
	day_length = float(p.get("day_length", 720))
	var s: Dictionary = p.get("sky", {})
	for k in ["top", "horizon", "fog", "sun", "night_top", "night_horizon", "moon"]:
		_c[k] = Color.html(s.get(k, "#808080"))
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("top_color", _c.top)
	sky_mat.set_shader_parameter("horizon_color", _c.horizon)
	sky_mat.set_shader_parameter("night_top", _c.night_top)
	sky_mat.set_shader_parameter("night_horizon", _c.night_horizon)
	sky_mat.set_shader_parameter("sun_color", _c.sun)
	sky_mat.set_shader_parameter("moon_color", _c.moon)
	sky_mat.set_shader_parameter("ring", 1.0 if s.get("ring", false) else 0.0)
	sky_mat.set_shader_parameter("space", 1.0 if s.get("space", false) else 0.0)
	sky_mat.set_shader_parameter("moon_dir", Vector3(-0.55, 0.32, -0.62).normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_sky_affect = 0.0
	env.fog_density = 1.0
	env.glow_enabled = glow
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)
	sun.shadow_enabled = false
	sun.light_energy = 1.0
	add_child(sun)


func set_view_distance(d: float) -> void:
	view_dist = d
	env.fog_depth_begin = d * 0.45
	env.fog_depth_end = d * 0.95


func _process(dt: float) -> void:
	time_of_day = fposmod(time_of_day + dt / day_length, 1.0)
	var a := (time_of_day - 0.25) * TAU
	sun_dir = Vector3(cos(a), sin(a), 0.38).normalized()
	daylight = smoothstep(-0.14, 0.22, sun_dir.y)
	var night := 1.0 - daylight
	var elev := clampf(sun_dir.y, 0.0, 1.0)
	var sunset_col := Color(1.0, 0.55, 0.32)
	var sun_c: Color = sunset_col.lerp(_c.sun, smoothstep(0.0, 0.35, elev)) * daylight
	var moon_c := Color(0.32, 0.36, 0.55) * night * 0.55
	var light_c: Color = sun_c + moon_c
	var light_dir := sun_dir if daylight > 0.05 else Vector3(-sun_dir.x, -sun_dir.y, 0.4).normalized()
	var day_amb: Color = _c.horizon.lerp(_c.top, 0.5) * 0.5 + Color(0.22, 0.22, 0.24)
	var night_amb: Color = Color(0.07, 0.07, 0.13) + _c.night_horizon * 0.35
	var amb: Color = night_amb.lerp(day_amb, daylight)
	var horizon: Color = _c.night_horizon.lerp(_c.horizon, daylight)
	var fogc: Color = horizon.lerp(_c.fog, 0.35)
	if storm > 0.0:
		fogc = fogc.lerp(storm_color * (0.25 + daylight * 0.75), storm)
		amb = amb.lerp(storm_color * 0.6 * (0.3 + daylight * 0.7), storm * 0.5)
		light_c = light_c * (1.0 - storm * 0.6)
		env.fog_depth_end = lerpf(view_dist * 0.95, 30.0, storm)
		env.fog_depth_begin = lerpf(view_dist * 0.45, 4.0, storm)
	env.fog_light_color = fogc
	env.ambient_light_color = amb
	env.ambient_light_energy = 1.0
	sun.light_color = light_c
	sun.light_energy = 1.0
	sun.look_at_from_position(Vector3.ZERO, -light_dir, Vector3.UP if absf(light_dir.y) < 0.99 else Vector3.FORWARD)
	var t := Time.get_ticks_msec() / 1000.0
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("night", night)
	sky_mat.set_shader_parameter("time_s", t)
	sky_mat.set_shader_parameter("storm", storm)
	sky_mat.set_shader_parameter("storm_color", storm_color)
	sky_mat.set_shader_parameter("horizon_color", _c.horizon.lerp(fogc, storm))
	for m in materials:
		m.set_shader_parameter("sun_dir", light_dir)
		m.set_shader_parameter("sun_color", light_c)
		m.set_shader_parameter("ambient_color", amb)
		m.set_shader_parameter("time_s", t)


func is_night() -> bool:
	return daylight < 0.3


func clock_text() -> String:
	var mins := int(time_of_day * 24.0 * 60.0)
	return "%02d:%02d" % [mins / 60, mins % 60]

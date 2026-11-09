class_name WorldRoot
extends Node3D
## Assembles one planet session: voxel world, sky, player, machines, HUD and menus.
## Owns autosave, survival environment, death/respawn and desktop input.

signal exit_to_title

const TF := preload("res://scripts/ui/theme_factory.gd")
const AUTOSAVE_S := 60.0

var planet: Dictionary
var world: VoxelWorld
var sky: SkyController
var player: Player
var machines := Machines.new()
var ui: CanvasLayer
var hud: Hud
var touch: TouchControls
var inv_screen: InventoryScreen
var pause_menu: PauseMenu
var loading: Control
var _loading_lbl: Label

var spawn_point := Vector3.ZERO
var is_new := true
var _pod_built := false
var _autosave_t := 0.0
var _lights_t := 0.0
var _biome_t := 0.0
var _perf_t := 0.0
var _fps_frames := 0
var _fps_time := 0.0
var _mouse_captured := false
var _dead_t := -1.0
var use_touch := true
var bot_driven := false


func start(pid: String, new_game: bool) -> void:
	is_new = new_game
	planet = Reg.planets[pid]
	use_touch = Game.settings.touch
	var mods := {} if new_game else Game.load_mods(pid)
	machines.rebuild(mods)
	world = VoxelWorld.new()
	world.radius = int(Game.settings.render_distance)
	add_child(world)
	world.setup(planet, Game.world_seed, mods)
	world.block_changed.connect(_on_block_changed)
	sky = SkyController.new()
	add_child(sky)
	sky.setup(planet, world.materials(), Game.settings.glow)
	sky.set_view_distance(world.radius * 16.0)
	player = Player.new()
	player.world = world
	player.gravity = float(planet.get("gravity", 9.0))
	add_child(player)
	player.cam.far = world.radius * 16.0 + 32.0
	player.toast.connect(func(t: String, c: Color) -> void: hud.toast(t, c))
	player.block_mined.connect(_on_mined)
	Game.crafted.connect(_on_crafted)
	if new_game:
		spawn_point = _find_spawn()
		player.global_position = spawn_point
		_starting_kit()
	else:
		var m := Game.meta
		var pd: Dictionary = m.get("player", {})
		spawn_point = m.get("spawn", Vector3(8, 80, 8))
		player.global_position = pd.get("pos", spawn_point)
		player.yaw = pd.get("yaw", 0.0)
		player.pitch = pd.get("pitch", 0.0)
		player.inv.from_data(pd.get("inv", []))
		player.stats.from_data(pd.get("stats", {}))
		player.stats.apply_upgrades(pd.get("upgrades", {}))
		player.xp = pd.get("xp", 0)
		player.snap_to_surface = false
		sky.time_of_day = m.get("time", 0.32)
		_pod_built = true
	world.focus = player.global_position
	_build_ui()
	_apply_settings()


func _find_spawn() -> Vector3:
	var g := world.gen
	var sea: int = planet.get("sea_level", 0)
	for r in range(0, 400, 8):
		for k in 12:
			var a := k * TAU / 12.0
			var x := int(cos(a) * r) + 8
			var z := int(sin(a) * r) + 8
			if planet.get("type", "terrain") != "terrain":
				return Vector3(x + 0.5, 100, z + 0.5)
			var h := g.surface_height(x, z)
			if h > sea + 2 and h < 90:
				var flat := absi(g.surface_height(x + 3, z) - h) + absi(g.surface_height(x, z + 3) - h)
				if flat <= 2 and _solid_ground(g, x, z, h):
					return Vector3(x + 0.5, h + 1.05, z + 0.5)
	return Vector3(8.5, 80, 8.5)


## True when the generated chunk really has ground at height h around (x, z), i.e. no cave
## entrance or carved hole at the landing site.
func _solid_ground(g: VoxelWorld.Gen, x: int, z: int, h: int) -> bool:
	var cx := x >> 4
	var cz := z >> 4
	var b := g.generate_chunk(cx, cz, {})
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var lx := (x + dx) - cx * 16
			var lz := (z + dz) - cz * 16
			if lx < 0 or lz < 0 or lx > 15 or lz > 15:
				continue
			for dy in range(0, 4):
				var id := b[(h - dy) + 128 * (lx + 16 * lz)]
				if Reg.solid[id] == 0:
					return false
	return true


func _starting_kit() -> void:
	var inv := player.inv
	inv.slots[8] = {"id": "multitool_1", "n": 1}
	inv.add("ration", 5)
	inv.add("o2_canister", 3)
	inv.add("power_cell", 2)
	inv.add("lamp", 6)
	player.selected = 0


func _build_pod() -> void:
	# Crash pod: hull pad, oxygen generator, med bay and lamps around the spawn point.
	var c := Vector3i(floori(spawn_point.x), floori(spawn_point.y), floori(spawn_point.z))
	var hull := Reg.block("hull")
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			world.set_block(c.x + dx, c.y - 1, c.z + dz, hull)
			for dy in range(0, 4):
				var id := world.get_block(c.x + dx, c.y + dy, c.z + dz)
				if id > 0 and Reg.kind[id] != Reg.Kind.FLUID:
					world.set_block(c.x + dx, c.y + dy, c.z + dz, 0)
	world.set_block(c.x + 3, c.y, c.z - 3, Reg.block("o2_generator"))
	world.set_block(c.x - 3, c.y, c.z - 3, Reg.block("medbay"))
	world.set_block(c.x + 3, c.y, c.z + 3, Reg.block("lamp"))
	world.set_block(c.x - 3, c.y, c.z + 3, Reg.block("lamp"))
	world.set_block(c.x, c.y, c.z - 3, Reg.block("crate"))
	_pod_built = true
	hud.toast("Crash pod deployed. The oxygen generator keeps the area breathable.", TF.CYAN)
	hud.toast("Mine basalt and ferrite ore, then craft a Fabricator (BAG).", TF.AMBER)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ThemeFactory.build()
	ui.add_child(root)
	hud = Hud.new()
	hud.player = player
	hud.sky = sky
	hud.info.planet = planet.name
	root.add_child(hud)
	touch = TouchControls.new()
	touch.player = player
	touch.hud = hud
	touch.visible = use_touch
	touch.enabled = use_touch
	touch.button_pressed.connect(_on_touch_button)
	root.add_child(touch)
	inv_screen = InventoryScreen.new()
	inv_screen.visible = false
	inv_screen.closed.connect(_on_inv_closed)
	root.add_child(inv_screen)
	pause_menu = PauseMenu.new()
	pause_menu.visible = false
	pause_menu.action.connect(_on_pause_action)
	root.add_child(pause_menu)
	loading = ColorRect.new()
	(loading as ColorRect).color = Color(0.02, 0.015, 0.05, 1.0)
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(loading)
	_loading_lbl = TF.label("Descending to %s..." % planet.name, 30, TF.CYAN)
	_loading_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_lbl.position = Vector2(-300, -20)
	_loading_lbl.custom_minimum_size = Vector2(600, 40)
	loading.add_child(_loading_lbl)


func _apply_settings() -> void:
	touch.sensitivity = float(Game.settings.sensitivity)
	hud.info.show_fps = Game.settings.show_fps
	sky.env.glow_enabled = Game.settings.glow
	sky.sky_mat.set_shader_parameter("clouds", 1.0 if Game.settings.clouds else 0.0)
	Game.apply_render_scale()
	var rd := int(Game.settings.render_distance)
	if rd != world.radius:
		world.radius = rd
		world._center = Vector2i(1 << 30, 1 << 30)
		sky.set_view_distance(rd * 16.0)
		player.cam.far = rd * 16.0 + 32.0


# ------------------------------------------------------------------ frame

func _process(dt: float) -> void:
	if world == null:
		return
	world.focus = player.global_position
	_fps_frames += 1
	_fps_time += dt
	if _fps_time >= 1.0:
		hud.info.fps = int(round(_fps_frames / _fps_time))
		_fps_frames = 0
		_fps_time = 0.0
	if loading.visible:
		var r := world.loaded_ratio()
		_loading_lbl.text = "Descending to %s...  %d%%" % [planet.name, int(r * 100)]
		if r >= 0.6 and not player.frozen:
			loading.visible = false
			if is_new and not _pod_built:
				var top := world.column_top(floori(spawn_point.x), floori(spawn_point.z))
				spawn_point.y = top + 1.05
				player.global_position = spawn_point
				player.vel = Vector3.ZERO
				_build_pod()
		return
	_perf_t += dt
	if _perf_t >= 5.0:
		_perf_t = 0.0
		print("[PERF] fps=%d chunks=%d pending=%d draw_calls=%d prims=%d mem_mb=%.0f" % [hud.info.fps, world.chunks.size(), world.pending_work(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			OS.get_static_memory_usage() / 1048576.0])
	hud.info.extra = "chunks %d  queue %d" % [world.chunks.size(), world.pending_work()]
	_desktop_input(dt)
	_update_environment(dt)
	_update_lights(dt)
	_update_death(dt)
	_autosave_t += dt
	if _autosave_t >= AUTOSAVE_S:
		_autosave_t = 0.0
		save()


func _update_environment(dt: float) -> void:
	var pos := player.global_position
	var head := pos + Vector3(0, 1.5, 0)
	var top := world.column_top(floori(pos.x), floori(pos.z))
	var exposed := top < 0 or head.y >= top
	var temp := float(planet.get("temp", 15.0)) - (1.0 - sky.daylight) * 14.0
	if not exposed:
		temp = lerpf(temp, float(planet.get("temp", 15.0)) + 6.0, 0.6)
	var o2_zone := machines.in_range("o2", head)
	var env := {
		"breathable": float(planet.get("o2", 0.0)) >= 0.95,
		"o2_zone": o2_zone,
		"in_fluid": player.head_in_fluid,
		"temp": temp,
		"heated": o2_zone or machines.in_range("heater", head),
		"rad": float(planet.get("rad", 0.0)) * (1.0 if exposed else 0.2),
		"sun": sky.daylight if exposed else 0.0,
		"drain": 0.25 if _lamp_on(exposed) else 0.0,
	}
	var fid := world.get_block(floori(pos.x), floori(pos.y + 0.3), floori(pos.z))
	if fid > 0 and Reg.block_def(fid).has("hazard"):
		env["hazard"] = float(Reg.block_def(fid).hazard)
		env["hazard_name"] = Reg.block_def(fid).label
	player.stats.update(dt, env)
	# helmet lamp
	var lamp := _lamp_on(exposed)
	for m in world.materials():
		m.set_shader_parameter("lamp_pos", player.eye_pos() + player.look_dir() * 1.5)
		m.set_shader_parameter("lamp_range", 11.0 if lamp else 0.01)
	_biome_t -= dt
	if _biome_t <= 0.0:
		_biome_t = 0.5
		if world.gen.biomes.size() > 0:
			var col := world.gen.column(floori(pos.x), floori(pos.z))
			hud.info.biome = world.gen.biomes[col[1]].name if exposed else "Underground"


func _lamp_on(exposed: bool) -> bool:
	return sky.daylight < 0.45 or not exposed or player.head_in_fluid


func _update_lights(dt: float) -> void:
	_lights_t -= dt
	if _lights_t > 0.0 and not world.lights_dirty:
		return
	_lights_t = 0.4
	world.lights_dirty = false
	var ls := world.nearest_lights(player.global_position, 8)
	var lp := []
	var lc := []
	for l in ls:
		lp.append(l)
		lc.append(Color(1.0, 0.86, 0.6, 1.0) * 1.1)
	while lp.size() < 8:
		lp.append(Vector4(0, -1000, 0, 1))
		lc.append(Color(0, 0, 0, 0))
	for m in world.materials():
		m.set_shader_parameter("lights_pos", PackedVector4Array(lp))
		m.set_shader_parameter("lights_col", PackedVector4Array(lc.map(func(c: Color) -> Vector4: return Vector4(c.r, c.g, c.b, c.a))))
		m.set_shader_parameter("light_count", ls.size())


func _update_death(dt: float) -> void:
	if _dead_t < 0.0 and player.stats.dead():
		_dead_t = 2.5
		hud.toast("Suit failure: " + player.stats.last_damage + ". Reconstructing at med bay...", TF.RED)
		player.set_process(false)
	if _dead_t >= 0.0:
		_dead_t -= dt
		if _dead_t < 0.0:
			var mb = machines.nearest("medbay", spawn_point, 100000.0)
			var p := spawn_point
			if mb != null:
				p = Vector3(mb) + Vector3(1.5, 0.05, 1.5)
			player.respawn(p)
			player.set_process(true)


# ------------------------------------------------------------------ events

func _on_block_changed(pos: Vector3i, old_id: int, new_id: int) -> void:
	machines.on_block_changed(pos, old_id, new_id)


func _on_mined(pos: Vector3i, id: int) -> void:
	var d := Reg.block_def(id)
	if d.get("loot", "") == "ruin":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(pos) ^ Game.world_seed
		var loot := [["artifact", 1], ["data_core", 1], ["circuit", rng.randi_range(1, 3)], ["lumen_shard", rng.randi_range(2, 5)], ["aurium_chunk", rng.randi_range(1, 4)]]
		for k in 3:
			var l: Array = loot[rng.randi() % loot.size()]
			player.inv.add(l[0], l[1])
			hud.toast("Recovered %s ×%d" % [Reg.item_label(l[0]), l[1]], TF.AMBER)


func _on_crafted(item: String, n: int) -> void:
	hud.toast("Fabricated %s ×%d" % [Reg.item_label(item), n], TF.GREEN)


func _on_touch_button(n: String) -> void:
	match n:
		"inv":
			open_inventory()
		"menu":
			open_pause()


func open_inventory() -> void:
	if pause_menu.visible:
		return
	touch.reset()
	touch.enabled = false
	_release_mouse()
	inv_screen.open(player, machines.stations_near(player.global_position, 5.5))
	player.set_process(false)


func _on_inv_closed() -> void:
	touch.enabled = use_touch
	player.set_process(true)
	_capture_mouse()


func open_pause() -> void:
	touch.reset()
	touch.enabled = false
	_release_mouse()
	pause_menu.visible = true
	pause_menu.set_status("")
	player.set_process(false)


func _on_pause_action(a: String) -> void:
	match a:
		"resume":
			pause_menu.visible = false
			touch.enabled = use_touch
			player.set_process(true)
			_capture_mouse()
		"save":
			save()
			pause_menu.set_status("Saved.")
		"settings":
			_apply_settings()
		"quit":
			save()
			exit_to_title.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if world != null and not loading.visible:
			save()


func save() -> void:
	if world == null or player == null:
		return
	var t0 := Time.get_ticks_msec()
	Game.save_mods(planet.id, world.mods)
	Game.write_meta({
		"spawn": spawn_point,
		"time": sky.time_of_day,
		"player": {
			"pos": player.global_position, "yaw": player.yaw, "pitch": player.pitch,
			"inv": player.inv.to_data(), "stats": player.stats.to_data(),
			"upgrades": player.stats.upgrades, "xp": player.xp,
		},
	})
	print("[SAVE] saved %d edited chunks in %d ms" % [world.mods.size(), Time.get_ticks_msec() - t0])


# ------------------------------------------------------------------ desktop

func _capture_mouse() -> void:
	if not use_touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = true


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false


func _unhandled_input(event: InputEvent) -> void:
	if use_touch or player == null:
		return
	if event is InputEventMouseMotion and _mouse_captured:
		player.ctl.look += event.relative * 0.0025 * float(Game.settings.sensitivity)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not _mouse_captured and mb.pressed and not inv_screen.visible and not pause_menu.visible:
			_capture_mouse()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			player.ctl.mine = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			player.ctl.place = true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			player.selected = posmod(player.selected - 1, 9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			player.selected = posmod(player.selected + 1, 9)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		if k >= KEY_1 and k <= KEY_9:
			player.selected = k - KEY_1
		elif k == KEY_E or k == KEY_TAB:
			if inv_screen.visible:
				inv_screen._on_close()
			else:
				open_inventory()
		elif k == KEY_ESCAPE:
			if inv_screen.visible:
				inv_screen._on_close()
			elif pause_menu.visible:
				_on_pause_action("resume")
			else:
				open_pause()
		elif k == KEY_F3:
			Game.settings.show_fps = not Game.settings.show_fps
			_apply_settings()


func _desktop_input(_dt: float) -> void:
	if use_touch or bot_driven or not player.is_processing():
		return
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		mv.y += 1
	if Input.is_key_pressed(KEY_S):
		mv.y -= 1
	if Input.is_key_pressed(KEY_D):
		mv.x += 1
	if Input.is_key_pressed(KEY_A):
		mv.x -= 1
	player.ctl.move = mv
	player.ctl.jump = Input.is_key_pressed(KEY_SPACE)
	player.ctl.sprint = Input.is_key_pressed(KEY_SHIFT)

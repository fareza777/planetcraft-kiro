class_name WorldRoot
extends Node3D
## Assembles one planet session and wires every system together: voxel world, sky, player,
## creatures/combat, machines/power, planet evolution, weather/events, quests, rover,
## starship travel, HUD and menus. Owns saving, survival environment and death/respawn.

signal exit_to_title
signal travel_to(planet_id: String)

const TF := preload("res://scripts/ui/theme_factory.gd")
const AUTOSAVE_S := 60.0

var planet: Dictionary
var world: VoxelWorld
var sky: SkyController
var player: Player
var machines: Machines
var creatures: Creatures
var evolution: Evolution
var events: WorldEvents
var quests := Quests.new()
var fx: Fx
var sfx: Sfx
var rover: Rover
var ship := {"hull": false, "nav": false, "engine": 0}
var ui: CanvasLayer
var hud: Hud
var touch: TouchControls
var inv_screen: InventoryScreen
var pause_menu: PauseMenu
var machine_panel: MachinePanel
var dialog: DialogPanel
var npcs: Npcs
var loading: Control
var fade: ColorRect
var _loading_lbl: Label

var mode := "new"
var spawn_point := Vector3.ZERO
var _pod_pending := false
var _autosave_t := 0.0
var _lights_t := 0.0
var _slow_t := 0.0
var _perf_t := 0.0
var _fps_frames := 0
var _fps_time := 0.0
var _mouse_captured := false
var _dead_t := -1.0
var _travel_t := -1.0
var _travel_to := ""
var _state: Dictionary = {}
var _ship_models: Dictionary = {}
var use_touch := true
var bot_driven := false
var _base_sky: Dictionary = {}


## mode: "new" (fresh game), "continue" (load save), "arrive" (landed after a jump)
func start(pid: String, start_mode: String) -> void:
	mode = start_mode
	planet = Reg.planets[pid]
	use_touch = Game.settings.touch
	var new_game := mode == "new"
	var mods := {} if new_game else Game.load_mods(pid)
	_state = {} if new_game else Game.load_state(pid)
	sfx = Sfx.new()
	add_child(sfx)
	fx = Fx.new()
	add_child(fx)
	fx.setup_ambient(planet)
	world = VoxelWorld.new()
	world.radius = int(Game.settings.render_distance)
	add_child(world)
	world.setup(planet, Game.world_seed, mods)
	world.block_changed.connect(_on_block_changed)
	sky = SkyController.new()
	add_child(sky)
	sky.setup(planet, world.materials(), Game.settings.glow)
	sky.set_view_distance(world.radius * 16.0)
	_base_sky = sky._c.duplicate()
	machines = Machines.new()
	machines.world = world
	machines.sky = sky
	add_child(machines)
	machines.rebuild(mods, _state)
	machines.produced.connect(func(t: String) -> void: hud.toast(t, TF.AMBER))
	evolution = Evolution.new()
	add_child(evolution)
	evolution.setup(planet, world, machines, _state.get("evolution", {}))
	evolution.milestone.connect(_on_milestone)
	player = Player.new()
	player.world = world
	player.gravity = float(planet.get("gravity", 9.0))
	player.fx = fx
	player.sfx = sfx
	add_child(player)
	player.cam.far = world.radius * 16.0 + 32.0
	player.toast.connect(func(t: String, c: Color) -> void: hud.toast(t, c))
	player.block_mined.connect(_on_mined)
	player.block_placed.connect(_on_placed)
	player.use_requested.connect(_on_use)
	creatures = Creatures.new()
	add_child(creatures)
	creatures.setup(world, player, fx, sfx, sky, planet)
	creatures.boss_done = _state.get("boss_done", false)
	creatures.killed.connect(func(id: String) -> void: quests.event("kill", id))
	creatures.tamed_creature.connect(func(id: String) -> void: quests.event("tame", id))
	creatures.boss_defeated.connect(_on_boss_defeated)
	player.combat = creatures
	events = WorldEvents.new()
	add_child(events)
	events.setup(world, sky, fx, sfx, player, planet, evolution)
	events.announce.connect(func(t: String, c: Color) -> void: hud.toast(t, c))
	events.creatures = creatures
	creatures.killed.connect(func(id: String) -> void: quests.record_kill(id))
	creatures.rare_drop.connect(func(src: String, item: String) -> void: quests.record_drop(src, item))
	quests.inv = player.inv
	quests.completed.connect(_on_quest_done)
	quests.started.connect(_on_quest_started)
	quests.side_ready.connect(func(q: Dictionary) -> void:
		sfx.play("quest", -6.0)
		hud.toast("Job ready to turn in: %s (%s)" % [q.title, Reg.npcs.get(q.giver, {}).get("name", "")], TF.GREEN))
	quests.side_done.connect(_on_side_done)
	Game.crafted.connect(_on_crafted)
	_load_player()
	npcs = Npcs.new()
	add_child(npcs)
	npcs.setup(world, player, planet, quests, _state, spawn_point)
	world.focus = player.global_position
	_build_ui()
	_apply_settings()


func _load_player() -> void:
	var m := Game.meta
	if mode == "new":
		spawn_point = _find_spawn()
		player.global_position = spawn_point
		_starting_kit()
		_pod_pending = true
		sky.time_of_day = 0.3
		return
	var pd: Dictionary = m.get("player", {})
	player.inv.from_data(pd.get("inv", []))
	player.stats.from_data(pd.get("stats", {}))
	player.stats.apply_upgrades(pd.get("upgrades", {}))
	player.xp = pd.get("xp", 0)
	ship = m.get("ship", ship)
	quests.from_data(m.get("quests", {}))
	if mode == "continue":
		spawn_point = _state.get("spawn", m.get("spawn", Vector3(8, 80, 8)))
		player.global_position = pd.get("pos", spawn_point)
		player.yaw = pd.get("yaw", 0.0)
		player.pitch = pd.get("pitch", 0.0)
		player.snap_to_surface = false
		sky.time_of_day = m.get("time", 0.32)
	else:
		if _state.has("spawn"):
			spawn_point = _state.spawn
			player.global_position = spawn_point + Vector3(2, 1, 0)
		else:
			spawn_point = _find_spawn()
			player.global_position = spawn_point
			_pod_pending = true
		sky.time_of_day = randf_range(0.25, 0.4)
	for pet in _state.get("pets", []):
		creatures.spawn(pet.id, pet.pos + Vector3(0, 0.5, 0), true)
	if _state.has("rover"):
		_spawn_rover(_state.rover)


func _find_spawn() -> Vector3:
	var g := world.gen
	var sea: int = planet.get("sea_level", 0)
	if planet.get("type", "terrain") != "terrain":
		for r in range(0, 200, 6):
			for k in 10:
				var a := k * TAU / 10.0
				var x := int(cos(a) * r) + 8
				var z := int(sin(a) * r) + 8
				var b := g.generate_chunk(x >> 4, z >> 4, {})
				var lx := x - (x >> 4) * 16
				var lz := z - (z >> 4) * 16
				for y in range(110, 20, -1):
					if Reg.solid[b[y + 128 * (lx + 16 * lz)]] == 1:
						return Vector3(x + 0.5, y + 1.05, z + 0.5)
		return Vector3(8.5, 80, 8.5)
	for r in range(0, 400, 8):
		for k in 12:
			var a := k * TAU / 12.0
			var x := int(cos(a) * r) + 8
			var z := int(sin(a) * r) + 8
			var h := g.surface_height(x, z)
			if h > sea + 2 and h < 90:
				var flat := absi(g.surface_height(x + 3, z) - h) + absi(g.surface_height(x, z + 3) - h)
				if flat <= 2 and _solid_ground(g, x, z, h):
					return Vector3(x + 0.5, h + 1.05, z + 0.5)
	return Vector3(8.5, 80, 8.5)


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
				if Reg.solid[b[(h - dy) + 128 * (lx + 16 * lz)]] == 0:
					return false
	return true


func _starting_kit() -> void:
	var inv := player.inv
	inv.slots[8] = {"id": "multitool_1", "n": 1}
	inv.add("ration", 5)
	inv.add("o2_canister", 3)
	inv.add("power_cell", 2)
	inv.add("lamp", 6)
	for kit in Game.owned_kits():
		for it in kit.get("items", []):
			inv.add(it[0], int(it[1]))
	player.selected = 0


func _build_pod() -> void:
	var c := Vector3i(floori(spawn_point.x), floori(spawn_point.y), floori(spawn_point.z))
	var hull := Reg.block("hull")
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			world.set_block(c.x + dx, c.y - 1, c.z + dz, hull)
			for dy in range(0, 5):
				var id := world.get_block(c.x + dx, c.y + dy, c.z + dz)
				if id > 0 and Reg.kind[id] != Reg.Kind.FLUID:
					world.set_block(c.x + dx, c.y + dy, c.z + dz, 0)
	world.set_block(c.x + 3, c.y, c.z - 3, Reg.block("o2_generator"))
	world.set_block(c.x + 3, c.y, c.z + 3, Reg.block("lamp"))
	world.set_block(c.x - 3, c.y, c.z + 3, Reg.block("lamp"))
	if mode == "new":
		world.set_block(c.x - 3, c.y, c.z - 3, Reg.block("medbay"))
		world.set_block(c.x, c.y, c.z - 3, Reg.block("crate"))
		world.set_block(c.x - 3, c.y, c.z, Reg.block("solar_panel"))
		world.set_block(c.x - 2, c.y, c.z - 3, Reg.block("battery"))
		hud.toast("Crash pod deployed. The oxygen generator keeps the area breathable.", TF.CYAN)
	else:
		world.set_block(c.x, c.y - 1, c.z + 2, Reg.block("launch_pad"))
		world.set_block(c.x - 3, c.y, c.z - 3, Reg.block("solar_panel"))
		hud.toast("Landed on %s. Ship parked on the launch pad." % planet.name, TF.CYAN)
	_pod_pending = false
	_state["spawn"] = spawn_point


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
	inv_screen.closed.connect(_on_modal_closed)
	root.add_child(inv_screen)
	machine_panel = MachinePanel.new()
	machine_panel.visible = false
	machine_panel.closed.connect(_on_modal_closed)
	machine_panel.travel.connect(_begin_travel)
	root.add_child(machine_panel)
	dialog = DialogPanel.new()
	dialog.visible = false
	dialog.closed.connect(_on_modal_closed)
	dialog.talked.connect(func(id: String) -> void: quests.event("talk", id))
	root.add_child(dialog)
	pause_menu = PauseMenu.new()
	pause_menu.visible = false
	pause_menu.action.connect(_on_pause_action)
	root.add_child(pause_menu)
	fade = ColorRect.new()
	fade.color = Color(0.85, 0.95, 1.0, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	loading = ColorRect.new()
	(loading as ColorRect).color = Color(0.02, 0.015, 0.05, 1.0)
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(loading)
	_loading_lbl = TF.label("", 30, TF.CYAN)
	_loading_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading.add_child(_loading_lbl)


func _apply_settings() -> void:
	touch.sensitivity = float(Game.settings.sensitivity)
	player.cam.fov = float(Game.settings.get("fov", 72))
	touch._layout()
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
	var focus := rover.global_position if (rover != null and rover.driving) else player.global_position
	world.focus = focus
	_fps_frames += 1
	_fps_time += dt
	if _fps_time >= 1.0:
		hud.info.fps = int(round(_fps_frames / _fps_time))
		_fps_frames = 0
		_fps_time = 0.0
	if loading.visible:
		var r := world.loaded_ratio()
		_loading_lbl.text = "%s %s...  %d%%\n\n%s" % ["Landing on" if mode == "arrive" else "Descending to", planet.name, int(r * 100), planet.desc]
		if r >= 0.6 and not player.frozen:
			loading.visible = false
			sfx.loop("ambient", true, -20.0, 1.0, 1.0)
			_on_arrived()
		return
	_perf_t += dt
	if _perf_t >= 5.0:
		_perf_t = 0.0
		print("[PERF] fps=%d chunks=%d pending=%d creatures=%d draw_calls=%d prims=%d mem_mb=%.0f" % [hud.info.fps, world.chunks.size(), world.pending_work(), creatures.list.size(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			OS.get_static_memory_usage() / 1048576.0])
	_desktop_input(dt)
	hud.info.driving = rover != null and rover.driving
	hud.info.banner = events.banner
	if rover != null and rover.driving:
		rover.drive(dt, player.ctl)
		player.global_position = rover.global_position + Vector3(0, 1.0, 0)
		if player.ctl.jump:
			_exit_rover()
		sfx.loop("rover", true, -10.0, 0.7 + rover.speed_kmh() / 60.0, dt)
	else:
		sfx.loop("rover", false, -10.0, 1.0, dt)
	machines.tick(dt, player.global_position)
	evolution.tick(dt)
	_update_environment(dt)
	_update_lights(dt)
	_update_death(dt)
	_update_travel(dt)
	fx.follow(player.global_position, sky.is_night())
	_slow_t -= dt
	if _slow_t <= 0.0:
		_slow_t = 1.0
		_slow_update()
	_autosave_t += dt
	if _autosave_t >= AUTOSAVE_S:
		_autosave_t = 0.0
		save()


func _slow_update() -> void:
	hud.info.quest = quests.tracker_text()
	quests.check_collect()
	var power := "⚡ %+.0f kW" % (machines.gen - machines.use) if machines.use > 0.0 or machines.gen > 0.0 else ""
	hud.info.extra = "%s  %s" % [power, ("🚙 %d km/h" % rover.speed_kmh()) if (rover != null and rover.driving) else ""]
	var c := evolution.sky_colors(_base_sky)
	for k in c:
		sky._c[k] = c[k]
	if float(evolution.stats.atmo) >= 1.0:
		quests.event("stat", "atmo")
	if float(evolution.stats.life) >= 1.0:
		quests.event("stat", "life")
	_update_ship_models()
	_update_waypoint()


## Nearest block of `id` around the player, using the native PackedByteArray.find over the
## loaded chunks in a 5×5 area (fast enough to run every second on the phone).
func _nearest_block(ids: Array, max_hits := 40) -> Variant:
	var pp := player.global_position
	var c := Vector2i(floori(pp.x) >> 4, floori(pp.z) >> 4)
	var best = null
	var bd := 1e18
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var col = world.chunks.get(c + Vector2i(dx, dz))
			if col == null:
				continue
			var blocks: PackedByteArray = col.blocks
			for id in ids:
				var i := blocks.find(id)
				var hits := 0
				while i >= 0 and hits < max_hits:
					hits += 1
					var y := i % 128
					var lx := (i / 128) % 16
					var lz := i / 2048
					var wp := Vector3(col.key.x * 16 + lx + 0.5, y + 0.5, col.key.y * 16 + lz + 0.5)
					var d := wp.distance_squared_to(pp) + (0.0 if y > pp.y - 6 else 200.0)
					if d < bd:
						bd = d
						best = wp
					i = blocks.find(id, i + 1)
	return best


func _blocks_for(goal: Dictionary) -> Array:
	var out := []
	match goal.type:
		"mine":
			var b := Reg.block(String(goal.id))
			if b > 0:
				out.append(b)
		"collect", "deliver":
			for bd in Reg.blocks:
				if bd.name != "air" and Reg.block_drop(bd.id) == goal.id and bd.get("place", true) != false:
					out.append(bd.id)
	return out


func _update_waypoint() -> void:
	var q := quests.current()
	hud.info.waypoint = null
	if q.is_empty():
		return
	var g: Dictionary = q.goal
	var targets := _blocks_for(g)
	if not targets.is_empty() and quests.goal_progress(q, quests.progress).x < quests.goal_progress(q, quests.progress).y:
		var p0 = _nearest_block(targets)
		if p0 != null:
			hud.info.waypoint = p0
			hud.info.wp_label = Reg.block_def(targets[0]).label
			return
	if g.type == "craft":
		var r := {}
		for rr in Reg.recipes:
			if rr.out == g.id:
				r = rr
				break
		var st: String = r.get("station", "hand")
		if st != "hand":
			var sp = machines.nearest(st, player.global_position, 400.0)
			if sp != null:
				hud.info.waypoint = Vector3(sp) + Vector3(0.5, 1.6, 0.5)
				hud.info.wp_label = Reg.item_label(st)
				return
	if g.type == "kill" or g.type == "tame":
		var best: Creature = null
		var bd := 1e9
		for c in creatures.list:
			if is_instance_valid(c) and c.alive and not c.tamed and (String(g.id) == "" or c.def.id == g.id) and (g.type != "tame" or c.def.get("tame", "") != ""):
				var d := c.global_position.distance_to(player.global_position)
				if d < bd:
					bd = d
					best = c
		if best != null:
			hud.info.waypoint = best.center() + Vector3(0, best.height, 0)
			hud.info.wp_label = best.def.name
			return
	if g.type == "talk":
		var p = npcs.position_of(g.id)
		if p != null:
			hud.info.waypoint = p + Vector3(0, 2.0, 0)
			hud.info.wp_label = Reg.npcs.get(g.id, {}).get("name", "Contact")
	elif g.type == "boss" and planet.has("boss") and not creatures.boss_done:
		hud.info.waypoint = Vector3(creatures.boss_pos.x, player.global_position.y + 8.0, creatures.boss_pos.z)
		hud.info.wp_label = "Anomaly"
	elif g.type == "ship" or (g.type == "visit_any" and planet.id == "verdania"):
		var pads := machines.positions("launchpad")
		if not pads.is_empty():
			hud.info.waypoint = Vector3(pads[0]) + Vector3(0.5, 3.0, 0.5)
			hud.info.wp_label = "Launch pad"
	if hud.info.waypoint == null:
		for sid in quests.side:
			if quests.side_complete(sid):
				var p2 = npcs.position_of(Reg.side_quests[sid].giver)
				if p2 != null:
					hud.info.waypoint = p2 + Vector3(0, 2.0, 0)
					hud.info.wp_label = "Turn in: " + Reg.side_quests[sid].title
					break


func _on_quest_started(q: Dictionary) -> void:
	if q.has("story"):
		hud.story(q.get("speaker", "ECHO"), q.story)


func _on_side_done(q: Dictionary) -> void:
	sfx.play("quest", 0.0)
	hud.toast("✔ Job complete: " + q.title, TF.GREEN)
	for r in q.get("reward", []):
		player.inv.add(r[0], int(r[1]))
		hud.toast("Reward: %s ×%d" % [Reg.item_label(r[0]), int(r[1])], TF.GREEN)
	player.xp += int(q.get("xp", 0))


func _update_environment(dt: float) -> void:
	var pos := player.global_position
	var head := pos + Vector3(0, 1.5, 0)
	var top := world.column_top(floori(pos.x), floori(pos.z))
	var exposed := top < 0 or head.y >= top
	var base_t := evolution.temperature_bias(float(planet.get("temp", 15.0)))
	var temp := base_t - (1.0 - sky.daylight) * 14.0
	if not exposed:
		temp = lerpf(temp, base_t + 6.0, 0.6)
	if events.weather == "blizzard":
		temp -= 25.0 * events.intensity
	var driving := rover != null and rover.driving
	var o2_zone := machines.in_range("o2", head) or driving
	var env := {
		"breathable": evolution.breathable(),
		"o2_zone": o2_zone,
		"in_fluid": player.head_in_fluid,
		"temp": temp,
		"heated": o2_zone or machines.in_range("heater", head),
		"rad": float(planet.get("rad", 0.0)) * (1.0 if exposed else 0.2) + float(evolution.stats.pollution) * 0.1,
		"sun": sky.daylight if exposed else 0.0,
		"drain": 0.25 if _lamp_on(exposed) else 0.0,
		"powered_zone": machines.powered and machines.count("battery") > 0 and machines.nearest("battery", pos, 6.0) != null,
	}
	var hz := events.exposure_damage(exposed and not driving)
	var fid := world.get_block(floori(pos.x), floori(pos.y + 0.3), floori(pos.z))
	if fid > 0 and Reg.block_def(fid).has("hazard"):
		hz += float(Reg.block_def(fid).hazard)
		env["hazard_name"] = Reg.block_def(fid).label
	elif hz > 0.0:
		env["hazard_name"] = events.weather.replace("_", " ")
	env["hazard"] = hz
	player.stats.update(dt, env)
	var lamp := _lamp_on(exposed)
	var lp := player.eye_pos() + player.look_dir() * 1.5
	if driving:
		lp = rover.global_position + Vector3(-sin(rover.heading), 0.4, -cos(rover.heading)) * 4.0
	for m in world.materials():
		m.set_shader_parameter("lamp_pos", lp)
		m.set_shader_parameter("lamp_range", (16.0 if driving else 11.0) if lamp else 0.01)
	if int(Time.get_ticks_msec() / 500) % 2 == 0 and world.gen.biomes.size() > 0:
		var col := world.gen.column(floori(pos.x), floori(pos.z))
		hud.info.biome = world.gen.biomes[col[1]].name if exposed else "Underground"
		fx.set_biome(world.gen.biomes[col[1]].id if exposed else "")


func _lamp_on(exposed: bool) -> bool:
	return sky.daylight < 0.45 or not exposed or player.head_in_fluid or events.intensity > 0.6


func _update_lights(dt: float) -> void:
	_lights_t -= dt
	if _lights_t > 0.0 and not world.lights_dirty:
		return
	_lights_t = 0.4
	world.lights_dirty = false
	var ls := world.nearest_lights(player.global_position, 8)
	var lp := PackedVector4Array()
	var lc := PackedVector4Array()
	for l in ls:
		lp.append(l)
		lc.append(Vector4(1.1, 0.95, 0.66, 1.0))
	while lp.size() < 8:
		lp.append(Vector4(0, -1000, 0, 1))
		lc.append(Vector4(0, 0, 0, 0))
	for m in world.materials():
		m.set_shader_parameter("lights_pos", lp)
		m.set_shader_parameter("lights_col", lc)
		m.set_shader_parameter("light_count", ls.size())


func _update_death(dt: float) -> void:
	if _dead_t < 0.0 and player.stats.dead():
		_dead_t = 2.5
		if rover != null and rover.driving:
			_exit_rover()
		hud.toast("Suit failure: " + player.stats.last_damage + ". Reconstructing at med bay...", TF.RED)
		sfx.play("die", 0.0, 0.6)
		player.set_process(false)
	if _dead_t >= 0.0:
		_dead_t -= dt
		fade.color = Color(0.4, 0.0, 0.05, clampf(1.0 - _dead_t / 2.5, 0.0, 0.8))
		if _dead_t < 0.0:
			fade.color.a = 0.0
			var mb = machines.nearest("medbay", spawn_point, 100000.0)
			var p := spawn_point
			if mb != null:
				p = Vector3(mb) + Vector3(1.5, 0.05, 1.5)
			player.respawn(p)
			player.set_process(true)


# ------------------------------------------------------------------ travel

func _begin_travel(pid: String) -> void:
	machine_panel.visible = false
	_on_modal_closed()
	_travel_to = pid
	_travel_t = 2.6
	sfx.play("warp", 0.0)
	player.shake(1.0)
	hud.toast("Engines spooling... destination: " + Reg.planets[pid].name, TF.CYAN)


func _update_travel(dt: float) -> void:
	if _travel_t < 0.0:
		return
	_travel_t -= dt
	player.shake(0.5)
	fade.color = Color(0.85, 0.95, 1.0, clampf(1.0 - _travel_t / 2.6, 0.0, 1.0))
	if _travel_t <= 0.0:
		_travel_t = -1.0
		Game.planet_id = _travel_to
		save()
		travel_to.emit(_travel_to)


func _on_arrived() -> void:
	if _pod_pending:
		var top := world.column_top(floori(spawn_point.x), floori(spawn_point.z))
		spawn_point.y = top + 1.05
		player.global_position = spawn_point
		player.vel = Vector3.ZERO
		_build_pod()
	quests.visited[planet.id] = true
	quests.event("visit", planet.id)
	if mode != "new" and _state.has("last_time"):
		var away := Time.get_unix_time_from_system() - float(_state.last_time)
		var rep := machines.simulate_offline(away)
		if rep.veggies + rep.ingots + rep.ore > 0:
			hud.toast("While you were away (%d min): +%d veggies, +%d ingots, +%d ore in machine storage" % [int(rep.seconds / 60), rep.veggies, rep.ingots, rep.ore], TF.GREEN)
	hud.toast(planet.name + " — " + planet.desc, TF.TEXT)
	var cq := quests.current()
	if mode == "new" and cq.has("story"):
		hud.story(cq.get("speaker", "ECHO"), cq.story)


# ------------------------------------------------------------------ events

func _on_block_changed(pos: Vector3i, old_id: int, new_id: int) -> void:
	var spilled := machines.on_block_changed(pos, old_id, new_id)
	for s in spilled:
		player.inv.add(s.id, int(s.n))


func _on_mined(pos: Vector3i, id: int) -> void:
	var d := Reg.block_def(id)
	evolution.on_mined()
	quests.event("mine", d.name)
	var center := Vector3(pos) + Vector3(0.5, 0.5, 0.5)
	var table: String = d.get("loot", "")
	if table != "":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(pos) ^ Game.world_seed ^ Time.get_ticks_msec()
		creatures.spawn_loot(center, Reg.roll_loot(table, rng), table)
		sfx.play("quest", -2.0)
		fx.sparks(center, Color(1, 0.8, 0.3), 30)
		if table == "ruin" and rng.randf() < 0.6:
			for k in 2:
				creatures.spawn("sentinel", center + Vector3(rng.randf_range(-6, 6), 6, rng.randf_range(-6, 6)), false, rng.randf() < 0.15)
			hud.toast("⚠ Precursor Sentinels activated!", TF.RED)
		elif table == "hive":
			for k in 4:
				creatures.spawn("hive_drone", center + Vector3(rng.randf_range(-3, 3), 1, rng.randf_range(-3, 3)))
			hud.toast("The hive shrieks! Its drones swarm out.", TF.RED)
			sfx.play("growl", 0.0, 1.4)
	elif d.name == "alien_hive" and randf() < 0.25:
		creatures.spawn("hive_drone", center + Vector3(randf_range(-2, 2), 1, randf_range(-2, 2)))


func _on_placed(pos: Vector3i, id: int) -> void:
	quests.event("place", Reg.block_def(id).name)


func _on_crafted(item: String, n: int) -> void:
	hud.toast("Fabricated %s ×%d" % [Reg.item_label(item), n], TF.GREEN)
	sfx.play("craft", -4.0)
	quests.event("craft", item, n)


func _on_quest_done(q: Dictionary) -> void:
	sfx.play("quest", 0.0)
	hud.celebrate(q.title)
	for r in q.get("reward", []):
		player.inv.add(r[0], int(r[1]))
		hud.toast("Reward: %s ×%d" % [Reg.item_label(r[0]), int(r[1])], TF.GREEN)
	player.xp += int(q.get("xp", 0))
	hud.info.quest = quests.tracker_text()


func _on_milestone(t: String) -> void:
	sfx.play("quest", 0.0)
	hud.toast("🌍 " + t, TF.GREEN)


func _on_boss_defeated() -> void:
	quests.event("boss", "")
	hud.toast("The Void Guardian has fallen. Its heart pulses with warp energy.", TF.AMBER)
	player.shake(1.0)


func _on_use() -> void:
	# 0) NPCs
	var npc := npcs.ray_npc(player.eye_pos(), player.look_dir(), 6.0)
	if npc != null:
		touch.reset()
		touch.enabled = false
		_release_mouse()
		player.set_process(false)
		dialog.open(self, npc.def.id)
		sfx.play("ui")
		return
	# 1) rover
	if rover != null and not rover.driving and _ray_hits(rover.global_position + Vector3(0, 1, 0), 1.8):
		_enter_rover()
		return
	# 2) structure events and machine panels
	if not player.target.is_empty():
		var id: int = player.target.id
		var ev: String = Reg.block_def(id).get("event", "")
		if ev == "trial":
			events.start_trial(player.target.pos)
			return
		elif ev == "starfall":
			events.start_starfall(player.target.pos)
			return
		if machines.is_interactive(id):
			_open_machine(player.target.pos, id)
			return
	# 3) deployables
	var s = player.inv.slots[player.selected]
	if s != null and Reg.item(s.id).get("type", "") == "deploy":
		if player.target.is_empty():
			hud.toast("Aim at the ground to deploy", TF.AMBER)
			return
		var p: Vector3i = player.target.pos
		_spawn_rover({"pos": Vector3(p) + Vector3(0.5, 1.2, 0.5), "heading": player.yaw})
		player.inv.remove_at(player.selected, 1)
		quests.event("deploy", "rover")
		sfx.play("place")
		hud.toast("Rover deployed. Tap USE while looking at it to drive. JUMP exits.", TF.CYAN)
		return
	player.use_selected()


func _ray_hits(center: Vector3, radius: float) -> bool:
	var o := player.eye_pos()
	var d := player.look_dir()
	var oc := center - o
	var t := oc.dot(d)
	return t > 0.0 and t < 7.0 and (oc - d * t).length() < radius


func _spawn_rover(d: Dictionary) -> void:
	if rover != null:
		rover.queue_free()
	rover = Rover.new()
	rover.world = world
	rover.gravity = float(planet.get("gravity", 9.0))
	add_child(rover)
	rover.global_position = d.get("pos", player.global_position)
	rover.heading = d.get("heading", 0.0)


func _enter_rover() -> void:
	rover.driving = true
	rover.cam.global_position = rover.global_position + Vector3(0, 4, 6)
	rover.cam.make_current()
	player.visible = false
	player.set_process(false)
	player.ctl.jump = false
	touch.reset()
	sfx.play("place", 0.0, 0.6)


func _exit_rover() -> void:
	rover.driving = false
	player.visible = true
	player.cam.make_current()
	var side := Vector3(cos(rover.heading), 0, -sin(rover.heading)) * 2.2
	player.global_position = rover.global_position + side + Vector3(0, 1.0, 0)
	player.vel = Vector3.ZERO
	player.set_process(true)
	player.ctl.jump = false


func _open_machine(pos: Vector3i, id: int) -> void:
	touch.reset()
	touch.enabled = false
	_release_mouse()
	machine_panel.open(self, pos, id)
	player.set_process(false)
	sfx.play("ui")


func _update_ship_models() -> void:
	var pads := machines.positions("launchpad")
	for p in _ship_models.keys():
		if not pads.has(p) or not ship.get("hull", false):
			_ship_models[p].queue_free()
			_ship_models.erase(p)
	if not ship.get("hull", false):
		return
	for p in pads:
		if not _ship_models.has(p):
			var m := _build_ship_model()
			add_child(m)
			m.global_position = Vector3(p) + Vector3(0.5, 1.0, 0.5)
			_ship_models[p] = m


func _build_ship_model() -> Node3D:
	var n := Node3D.new()
	var liv: Array = Game.cosmetic("ship")
	var parts := [
		[Vector3(2.2, 1.2, 5.0), Vector3(0, 1.6, 0), liv[0], false],
		[Vector3(1.6, 0.9, 1.8), Vector3(0, 2.4, -1.4), liv[2], true],
		[Vector3(6.5, 0.25, 2.2), Vector3(0, 1.4, 0.8), Color("30374a"), false],
		[Vector3(6.6, 0.12, 0.3), Vector3(0, 1.55, 1.8), liv[1], false],
		[Vector3(0.9, 0.9, 1.2), Vector3(-1.4, 1.5, 2.6), Color("2a2f3c"), false],
		[Vector3(0.9, 0.9, 1.2), Vector3(1.4, 1.5, 2.6), Color("2a2f3c"), false],
		[Vector3(0.6, 0.6, 0.2), Vector3(-1.4, 1.5, 3.25), Color("ffb02e"), true],
		[Vector3(0.6, 0.6, 0.2), Vector3(1.4, 1.5, 3.25), Color("ffb02e"), true],
		[Vector3(0.2, 1.0, 0.2), Vector3(-1.2, 0.5, -1.2), Color("5e6777"), false],
		[Vector3(0.2, 1.0, 0.2), Vector3(1.2, 0.5, -1.2), Color("5e6777"), false],
		[Vector3(0.2, 1.0, 0.2), Vector3(0, 0.5, 2.0), Color("5e6777"), false],
		[Vector3(0.3, 1.4, 1.6), Vector3(0, 2.6, 2.2), liv[0], false],
	]
	for pt in parts:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = pt[0]
		mi.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = pt[2]
		if pt[3]:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = pt[2] * 1.4
		mi.material_override = m
		mi.position = pt[1]
		n.add_child(mi)
	return n


# ------------------------------------------------------------------ menus

func _on_touch_button(n: String) -> void:
	match n:
		"inv":
			open_inventory()
		"menu":
			open_pause()


func open_inventory() -> void:
	if pause_menu.visible or machine_panel.visible:
		return
	touch.reset()
	touch.enabled = false
	_release_mouse()
	inv_screen.open(player, machines.stations_near(player.global_position, 5.5), quests, evolution)
	player.set_process(false)
	sfx.play("ui")


func _on_modal_closed() -> void:
	touch.enabled = use_touch
	if rover == null or not rover.driving:
		player.set_process(true)
	_capture_mouse()


func open_pause() -> void:
	touch.reset()
	touch.enabled = false
	_release_mouse()
	pause_menu.visible = true
	pause_menu.set_status(evolution.summary())
	player.set_process(false)


func _on_pause_action(a: String) -> void:
	match a:
		"resume":
			pause_menu.visible = false
			_on_modal_closed()
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
		if world != null and loading != null and not loading.visible:
			save()


func save() -> void:
	if world == null or player == null:
		return
	var t0 := Time.get_ticks_msec()
	Game.save_mods(planet.id, world.mods)
	var st := machines.save_data()
	st["evolution"] = evolution.stats
	st["pets"] = creatures.pets_data()
	st["boss_done"] = creatures.boss_done
	st["spawn"] = spawn_point
	st["last_time"] = Time.get_unix_time_from_system()
	if rover != null:
		st["rover"] = {"pos": rover.global_position, "heading": rover.heading}
	st.merge(npcs.save_data(), true)
	Game.save_state(planet.id, st)
	Game.write_meta({
		"spawn": spawn_point,
		"time": sky.time_of_day,
		"ship": ship,
		"quests": quests.to_data(),
		"player": {
			"pos": player.global_position, "yaw": player.yaw, "pitch": player.pitch,
			"inv": player.inv.to_data(), "stats": player.stats.to_data(),
			"upgrades": player.stats.upgrades, "xp": player.xp,
		},
	})
	print("[SAVE] %s: %d edited chunks in %d ms" % [planet.id, world.mods.size(), Time.get_ticks_msec() - t0])


# ------------------------------------------------------------------ desktop

func _capture_mouse() -> void:
	if not use_touch and not bot_driven:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = true


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false


func _unhandled_input(event: InputEvent) -> void:
	if use_touch or player == null or bot_driven:
		return
	if event is InputEventMouseMotion and _mouse_captured:
		player.ctl.look += event.relative * 0.0025 * float(Game.settings.sensitivity)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not _mouse_captured and mb.pressed and not inv_screen.visible and not pause_menu.visible and not machine_panel.visible:
			_capture_mouse()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			player.ctl.mine = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			player.ctl.place = true
			if rover != null and rover.driving:
				_exit_rover()
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
			elif machine_panel.visible:
				machine_panel._close()
			else:
				open_inventory()
		elif k == KEY_F:
			_on_use()
		elif k == KEY_ESCAPE:
			if inv_screen.visible:
				inv_screen._on_close()
			elif machine_panel.visible:
				machine_panel._close()
			elif pause_menu.visible:
				_on_pause_action("resume")
			else:
				open_pause()
		elif k == KEY_F3:
			Game.settings.show_fps = not Game.settings.show_fps
			_apply_settings()


func _desktop_input(_dt: float) -> void:
	if use_touch or bot_driven:
		return
	if not player.is_processing() and not (rover != null and rover.driving):
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

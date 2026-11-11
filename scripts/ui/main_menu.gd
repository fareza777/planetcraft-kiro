class_name MainMenu
extends Node3D
## Title screen: a live voxel planet orbits behind an animated menu.

signal start_game(new_game: bool)

const TF := preload("res://scripts/ui/theme_factory.gd")


class LogoMark:
	extends Control
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.3
		for i in 6:
			draw_circle(c, r * (1.6 - i * 0.1), Color(0.31, 0.89, 1.0, 0.025))
		# back half of ring
		_ring(c, r, true)
		for i in 24:
			var k := i / 23.0
			draw_circle(c + Vector2(-r * 0.25, -r * 0.25) * k * 0.3, r * (1.0 - k * 0.55), Color(0.18, 0.65, 0.58).lerp(Color(0.35, 0.95, 0.85), k))
		draw_arc(c, r, PI * 0.15, PI * 1.05, 32, Color(0.35, 0.12, 0.55, 0.55), r * 0.35, true)
		_ring(c, r, false)

	func _ring(c: Vector2, r: float, back: bool) -> void:
		var tilt := -0.25 + sin(t * 0.6) * 0.05
		var pts := PackedVector2Array()
		for i in 49:
			var a := i / 48.0 * TAU
			var front := sin(a) > 0.0
			if front == back:
				if pts.size() > 1:
					draw_polyline(pts, Color(1.0, 0.69, 0.18, 0.95), 5.0, true)
				pts.clear()
				continue
			var p := Vector2(cos(a) * r * 1.75, sin(a) * r * 0.42).rotated(tilt)
			pts.append(c + p)
		if pts.size() > 1:
			draw_polyline(pts, Color(1.0, 0.69, 0.18, 0.95), 5.0, true)


var world: VoxelWorld
var sky: SkyController
var cam: Camera3D
var _angle := 0.0
var _seed_edit: LineEdit
var _center := Vector3(8, 60, 8)
var _root: Control
var _menu: VBoxContainer
var _overlay: Control
var _overlay_body: VBoxContainer
var _title: Label
var _ticker: Label
var _ticker_i := 0
var _ticker_t := 0.0
var _t := 0.0


func _ready() -> void:
	var p: Dictionary = Reg.planets["verdania"]
	world = VoxelWorld.new()
	world.radius = 4 if OS.has_feature("mobile") else 5
	add_child(world)
	world.setup(p, 20261031, {})
	world.focus = _center
	sky = SkyController.new()
	add_child(sky)
	sky.setup(p, world.materials(), Game.settings.glow)
	sky.set_view_distance(world.radius * 16.0)
	sky.time_of_day = 0.66
	sky.day_length = 600.0
	cam = Camera3D.new()
	cam.fov = 62
	cam.far = 200
	add_child(cam)
	_center.y = float(world.gen.surface_height(8, 8)) + 6.0
	if Game.has_save() and Game.meta.is_empty():
		Game.load_meta()
		Game.continue_requested = false
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = ThemeFactory.build()
	layer.add_child(_root)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.01, 0.06, 0.92))
	g.set_color(1, Color(0.02, 0.01, 0.06, 0.0))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = grad
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.anchor_right = 0.62
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var logo := LogoMark.new()
	logo.position = Vector2(40, 20)
	logo.size = Vector2(150, 150)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(logo)
	_title = TF.label("PLANETCRAFT", 72, TF.CYAN)
	_title.position = Vector2(205, 34)
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.add_theme_color_override("font_shadow_color", Color(0.1, 0.0, 0.25, 0.9))
	_root.add_child(_title)
	var sub := TF.label("G A L A C T I C   S U R V I V A L", 22, TF.AMBER)
	sub.position = Vector2(212, 120)
	_root.add_child(sub)
	var menu_scroll := ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	menu_scroll.offset_left = 48
	menu_scroll.offset_top = 168
	menu_scroll.offset_bottom = -52
	menu_scroll.custom_minimum_size.x = 500
	_root.add_child(menu_scroll)
	TouchScroll.attach(menu_scroll)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	menu_scroll.add_child(_menu)
	if Game.has_save() and not Game.meta.is_empty():
		_menu.add_child(_save_card())
	_menu.add_child(_menu_button("NEW EXPEDITION", "Generate a new star system from a seed", _show_new, TF.CYAN))
	_menu.add_child(_menu_button("STELLAR STORE", "%d shards · suits, lasers, rovers, ships, kits" % int(Game.profile.shards), _show_store, Color(1.0, 0.75, 0.2)))
	_menu.add_child(_menu_button("SETTINGS", "Graphics, controls, audio", _show_settings, TF.CYAN))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_menu.add_child(row)
	for b in [["ABOUT", _show_about, Color(0.75, 0.5, 1.0)], ["RATE", _rate, TF.AMBER], ["SHARE", _share, TF.GREEN], ["QUIT", func() -> void: get_tree().quit(), TF.RED]]:
		var mb := _menu_button(b[0], "", b[1], b[2])
		mb.custom_minimum_size = Vector2(109, 52)
		mb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		mb.text = b[0]
		mb.add_theme_font_size_override("font_size", 17)
		row.add_child(mb)
	_ticker = TF.label("", 17, TF.TEXT)
	_ticker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ticker.position = Vector2(-680, -96)
	_ticker.custom_minimum_size = Vector2(640, 60)
	_ticker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_ticker)
	var foot := TF.label("v%s  ·  offline  ·  every texture, model and sound is generated in-engine" % ProjectSettings.get_setting("application/config/version"), 15, TF.DIM)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(64, -40)
	_root.add_child(foot)
	_build_overlay()
	UiAnim.slide_in(_title, Vector2(0, -30), 0.0, 0.6)
	UiAnim.slide_in(sub, Vector2(0, -20), 0.15, 0.6)
	await get_tree().process_frame
	var i := 0
	for c in _menu.get_children():
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(0.25 + i * 0.08)
		i += 1
	_next_ticker()


func _menu_button(text: String, hint: String, cb: Callable, accent: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(460, 66 if hint != "" else 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = ("   " + text + ("\n   " + hint if hint != "" else ""))
	b.add_theme_font_size_override("font_size", 20)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.05, 0.06, 0.14, 0.82)
	n.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	n.border_width_left = 6
	n.set_corner_radius_all(10)
	n.content_margin_left = 14
	var hv: StyleBoxFlat = n.duplicate()
	hv.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	hv.border_width_left = 10
	var pr: StyleBoxFlat = hv.duplicate()
	pr.bg_color = Color(accent.r, accent.g, accent.b, 0.4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_color_override("font_color", TF.TEXT)
	b.pressed.connect(func() -> void:
		UiAnim.bounce(b, 0.95)
		cb.call())
	return b


func _save_card() -> Control:
	var m := Game.meta
	var pl: Dictionary = Reg.planets.get(String(m.get("planet", "verdania")), {})
	var ago := int(Time.get_unix_time_from_system() - float(m.get("saved_at", 0)))
	var ago_t := "%d min ago" % (ago / 60) if ago < 3600 else ("%d h ago" % (ago / 3600) if ago < 86400 else "%d days ago" % (ago / 86400))
	var q := int(m.get("quests", {}).get("index", 0))
	var b := _menu_button("CONTINUE", "%s  ·  directive %d/%d  ·  saved %s" % [pl.get("name", "?"), q + 1, Reg.quests.size(), ago_t], _on_continue, TF.GREEN)
	b.custom_minimum_size.y = 72
	return b


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var pc := PanelContainer.new()
	pc.name = "Card"
	pc.add_theme_stylebox_override("panel", TF.box(Color(0.03, 0.03, 0.08, 0.97), TF.LINE, 18, 2, 24))
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.anchor_left = 0.12
	pc.anchor_right = 0.88
	pc.anchor_top = 0.08
	pc.anchor_bottom = 0.92
	pc.offset_left = 0
	pc.offset_right = 0
	pc.offset_top = 0
	pc.offset_bottom = 0
	_overlay.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := TF.label("", 30, TF.CYAN)
	t.name = "Title"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(TF.button("✕", _hide_overlay, 64))
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_overlay_body = VBoxContainer.new()
	_overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_overlay_body)


func _open_overlay(title: String) -> void:
	for c in _overlay_body.get_children():
		c.queue_free()
	(_overlay.find_child("Title", true, false) as Label).text = title
	_overlay.visible = true
	var card: Control = _overlay.get_node("Card")
	await get_tree().process_frame
	UiAnim.pop_in(card, 0.0, 0.92)


func _hide_overlay() -> void:
	_overlay.visible = false


func _show_new() -> void:
	await _open_overlay("NEW EXPEDITION")
	var l := TF.label("Every seed creates a different set of worlds: terrain, caves, ruins and ores. Your crash pod lands on Verdania.", 18, TF.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_child(l)
	var row := HBoxContainer.new()
	_overlay_body.add_child(row)
	row.add_child(TF.label("Seed", 22))
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(randi() % 1000000)
	_seed_edit.custom_minimum_size = Vector2(280, 56)
	_seed_edit.add_theme_font_size_override("font_size", 24)
	_seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	row.add_child(_seed_edit)
	row.add_child(TF.button("🎲 Random", func() -> void:
		_seed_edit.text = str(randi() % 1000000)
		UiAnim.bounce(_seed_edit), 180))
	if Game.has_save():
		_overlay_body.add_child(TF.label("⚠ Starting a new expedition overwrites your current save.", 17, TF.RED))
	var go := TF.button("LAUNCH", _on_new, 300)
	go.custom_minimum_size.y = 70
	go.add_theme_font_size_override("font_size", 26)
	go.add_theme_stylebox_override("normal", TF.box(Color(0.12, 0.38, 0.32, 0.95), TF.GREEN, 14, 2, 18))
	go.add_theme_stylebox_override("hover", TF.box(Color(0.16, 0.48, 0.4, 0.95), TF.GREEN, 14, 2, 18))
	_overlay_body.add_child(go)
	var worlds := TF.label("WORLDS IN THIS SYSTEM", 18, TF.AMBER)
	_overlay_body.add_child(worlds)
	for pid in Reg.planet_order:
		var p: Dictionary = Reg.planets[pid]
		var h := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = Color.html(p.color)
		sw.custom_minimum_size = Vector2(18, 18)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var d := TF.label("%s (tier %d) — %s" % [p.name, int(p.tier), p.desc], 16, TF.TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(d)
		_overlay_body.add_child(h)


func _show_store() -> void:
	await _open_overlay("STELLAR STORE")
	_overlay_body.add_child(StoreScreen.new())


func _show_settings() -> void:
	await _open_overlay("SETTINGS")
	var sp := SettingsPanel.new()
	sp.changed.connect(_apply_settings)
	_overlay_body.add_child(sp)


func _apply_settings() -> void:
	Game.apply_render_scale()
	Game.apply_audio()
	sky.env.glow_enabled = Game.settings.glow
	sky.sky_mat.set_shader_parameter("clouds", 1.0 if Game.settings.clouds else 0.0)


func _rate() -> void:
	Platform.rate()


func _share() -> void:
	var text := "I'm surviving alien worlds in PlanetCraft: Galactic Survival, an offline voxel sandbox for Android. %s" % Platform.REPO_URL
	if not Platform.share(text):
		_ticker.text = "Link copied to clipboard"
		_ticker.modulate.a = 1.0


func _show_about() -> void:
	await _open_overlay("ABOUT")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_overlay_body.add_child(head)
	var ic := TextureRect.new()
	ic.texture = load("res://art/generated/icon_192.png")
	ic.custom_minimum_size = Vector2(110, 110)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(ic)
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(TF.label("PlanetCraft: Galactic Survival", 26, TF.CYAN))
	hv.add_child(TF.label("Version %s  ·  F7 Developer" % ProjectSettings.get_setting("application/config/version"), 17, TF.DIM))
	var links := HBoxContainer.new()
	hv.add_child(links)
	links.add_child(TF.button("Rate", _rate, 120))
	links.add_child(TF.button("Share", _share, 120))
	links.add_child(TF.button("Source code", func() -> void: Platform.open_url(Platform.REPO_URL), 180))
	links.add_child(TF.button("Licenses", func() -> void: Platform.open_url(Platform.REPO_URL + "/blob/main/THIRD_PARTY_NOTICES.md"), 150))
	var stats := TF.label("Lifetime Stellar Shards found: %d" % int(Game.profile.get("lifetime", 0)), 16, TF.AMBER)
	_overlay_body.add_child(stats)
	var privacy := TF.label("Privacy: the game collects no personal data. Saves, settings and purchases stay on this device. Rate, Share, Source code and Licenses open other apps only when you tap them.", 15, TF.DIM)
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_child(privacy)
	var txt := """PlanetCraft: Galactic Survival is an original offline voxel sandbox by F7 Developer.

Survive on alien worlds, mine and build, automate a colony, tame creatures, fly between six worlds and terraform dead planets into living ones.

Everything you see and hear is generated by the game's own code at startup: block textures, item icons, creature bodies, the sky and every sound effect. No third-party art or audio assets are used.

Built with Godot Engine 4.7 (MIT licence) and developed with Kiro. Source code: MIT licence."""
	var l := TF.label(txt, 19, TF.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_child(l)


func _on_continue() -> void:
	if Game.load_meta():
		_go(false)


func _on_new() -> void:
	var s := int(_seed_edit.text) if _seed_edit.text.is_valid_int() else hash(_seed_edit.text)
	Game.start_new(s)
	_go(true)


func _go(new_game: bool) -> void:
	world.shutdown()
	start_game.emit(new_game)


func _next_ticker() -> void:
	var pid: String = Reg.planet_order[_ticker_i % Reg.planet_order.size()]
	var p: Dictionary = Reg.planets[pid]
	_ticker.text = "%s\n%s" % [p.name.to_upper(), p.desc]
	_ticker.add_theme_color_override("font_color", Color.html(p.color).lightened(0.3))
	_ticker.modulate.a = 0.0
	var tw := _ticker.create_tween()
	tw.tween_property(_ticker, "modulate:a", 1.0, 0.8)
	_ticker_i += 1


func _process(dt: float) -> void:
	_t += dt
	_angle += dt * 0.05
	var p := _center + Vector3(cos(_angle) * 36.0, 13.0 + sin(_t * 0.2) * 3.0, sin(_angle) * 36.0)
	cam.global_position = p
	cam.look_at(_center + Vector3(0, -4, 0), Vector3.UP)
	world.focus = _center
	for m in world.materials():
		m.set_shader_parameter("lamp_range", 0.01)
	if _title != null:
		var k := 0.5 + 0.5 * sin(_t * 1.5)
		_title.add_theme_color_override("font_color", TF.CYAN.lerp(Color(0.75, 1.0, 1.0), k * 0.5))
	_ticker_t += dt
	if _ticker_t > 6.0 and _ticker != null:
		_ticker_t = 0.0
		var tw := _ticker.create_tween()
		tw.tween_property(_ticker, "modulate:a", 0.0, 0.5)
		tw.tween_callback(_next_ticker)

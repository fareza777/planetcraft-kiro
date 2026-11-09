class_name SettingsPanel
extends VBoxContainer
## Shared settings UI (title screen and pause menu). Changes apply immediately and are saved.

signal changed

const TF := preload("res://scripts/ui/theme_factory.gd")

var _rows := {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section("GRAPHICS", TF.CYAN)
	_slider("render_distance", "View distance", 3, 10, 1, func(v: float) -> String: return "%d chunks (%d m)" % [int(v), int(v) * 16])
	_slider("render_scale", "Resolution", 0.4, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))
	_toggle("glow", "Bloom glow", "Soft glow on crystals and lamps. Costs GPU time on phones.")
	_toggle("clouds", "Sky clouds", "Animated cloud layer.")
	_toggle("show_fps", "Show FPS", "Frame counter in the corner.")
	_section("CONTROLS", TF.AMBER)
	_slider("sensitivity", "Look sensitivity", 0.3, 3.0, 0.1, func(v: float) -> String: return "%.1f×" % v)
	_slider("button_scale", "Touch button size", 0.7, 1.4, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))
	_toggle("invert_y", "Invert look Y", "Drag up to look down.")
	_section("AUDIO", TF.GREEN)
	_slider("master_volume", "Master volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))
	_slider("ambience", "Ambience", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))


func _section(t: String, c: Color) -> void:
	var l := TF.label(t, 18, c)
	if get_child_count() > 0:
		var sp := Control.new()
		sp.custom_minimum_size.y = 6
		add_child(sp)
	add_child(l)
	var line := ColorRect.new()
	line.color = Color(c.r, c.g, c.b, 0.35)
	line.custom_minimum_size.y = 2
	add_child(line)


func _row(label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l := TF.label(label, 19)
	l.custom_minimum_size.x = 220
	h.add_child(l)
	add_child(h)
	return h


func _slider(key: String, label: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var h := _row(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings.get(key, lo))
	s.custom_minimum_size = Vector2(260, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := TF.box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.18), 6, 1, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)
	var fill := TF.box(TF.CYAN, Color(0, 0, 0, 0), 6, 0, 0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _knob(false))
	s.add_theme_icon_override("grabber_highlight", _knob(true))
	h.add_child(s)
	var v := TF.label(fmt.call(s.value), 18, TF.DIM)
	v.custom_minimum_size.x = 150
	h.add_child(v)
	s.value_changed.connect(func(val: float) -> void:
		Game.settings[key] = int(val) if key == "render_distance" else val
		v.text = fmt.call(val)
		Game.save_settings()
		changed.emit())
	_rows[key] = s


func _toggle(key: String, label: String, hint: String) -> void:
	var h := _row(label)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = bool(Game.settings.get(key, false))
	b.custom_minimum_size = Vector2(110, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.text = "ON" if b.button_pressed else "OFF"
	b.add_theme_stylebox_override("pressed", TF.box(Color(0.15, 0.5, 0.45, 0.95), TF.GREEN, 22, 2, 10))
	b.add_theme_stylebox_override("normal", TF.box(Color(0.1, 0.1, 0.18, 0.95), Color(1, 1, 1, 0.2), 22, 2, 10))
	b.add_theme_stylebox_override("hover", TF.box(Color(0.14, 0.16, 0.26, 0.95), TF.CYAN, 22, 2, 10))
	b.add_theme_stylebox_override("hover_pressed", TF.box(Color(0.18, 0.55, 0.5, 0.95), TF.GREEN, 22, 2, 10))
	h.add_child(b)
	var hl := TF.label(hint, 15, TF.DIM)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(hl)
	b.toggled.connect(func(on: bool) -> void:
		Game.settings[key] = on
		b.text = "ON" if on else "OFF"
		UiAnim.bounce(b)
		Game.save_settings()
		changed.emit())
	_rows[key] = b


static func _knob(hi: bool) -> Texture2D:
	var img := Image.create_empty(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d < 12.5:
				var c := Color(1, 1, 1) if d < 9.0 else TF.CYAN
				if hi and d < 9.0:
					c = TF.AMBER.lightened(0.4)
				img.set_pixel(x, y, c)
			elif d < 13.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0.6))
	return ImageTexture.create_from_image(img)

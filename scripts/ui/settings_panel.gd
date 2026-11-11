class_name SettingsPanel
extends VBoxContainer
## Shared settings UI (title screen and pause menu). Changes apply immediately and are saved.

signal changed

const TF := preload("res://scripts/ui/theme_factory.gd")
const PRESETS := {
	"LOW": {"render_distance": 4, "render_scale": 0.5, "glow": false, "clouds": false},
	"MEDIUM": {"render_distance": 5, "render_scale": 0.6, "glow": false, "clouds": true},
	"HIGH": {"render_distance": 6, "render_scale": 0.8, "glow": true, "clouds": true},
	"ULTRA": {"render_distance": 8, "render_scale": 1.0, "glow": true, "clouds": true},
}

var _rows := {}
var _fmt := {}
var _confirm_delete := false
var _delete_btn: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section("GRAPHICS", TF.CYAN)
	var pr := HBoxContainer.new()
	pr.add_child(_label("Quality preset"))
	for p in PRESETS:
		var b := TF.button(p, _preset.bind(p), 110)
		b.custom_minimum_size.y = 46
		pr.add_child(b)
	add_child(pr)
	_slider("render_distance", "View distance", 3, 10, 1, func(v: float) -> String: return "%d chunks (%d m)" % [int(v), int(v) * 16])
	_slider("render_scale", "Resolution", 0.4, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))
	_slider("fov", "Field of view", 60, 95, 1, func(v: float) -> String: return "%d°" % int(v))
	_toggle("glow", "Bloom glow", "Soft glow on crystals and lamps. Costs GPU time on phones.")
	_toggle("clouds", "Sky clouds", "Animated cloud layer.")
	_toggle("show_fps", "Show FPS", "Frame counter in the corner.")
	_section("GAMEPLAY", TF.GREEN)
	_toggle("auto_jump", "Auto-jump", "Step up one-block ledges automatically while walking.")
	_toggle("camera_shake", "Camera shake", "Shake on impacts, explosions and heavy weapons.")
	_toggle("damage_numbers", "Damage numbers", "Floating numbers when you hit creatures.")
	_toggle("haptics", "Vibration", "Short haptic pulses when you take damage or break blocks.")
	_section("CONTROLS", TF.AMBER)
	_slider("sensitivity", "Look sensitivity", 0.3, 3.0, 0.1, func(v: float) -> String: return "%.1f×" % v)
	_slider("button_scale", "Touch button size", 0.7, 1.4, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))
	_toggle("invert_y", "Invert look Y", "Drag up to look down.")
	_section("AUDIO", Color(0.77, 0.54, 1.0))
	_slider("master_volume", "Master volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))
	_slider("ambience", "Music & ambience", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100)))
	_section("DATA", TF.RED)
	var dr := HBoxContainer.new()
	dr.add_child(_label("Storage"))
	dr.add_child(TF.button("Reset settings", _reset, 200))
	_delete_btn = TF.button("Delete expedition save", _delete_save, 270)
	_delete_btn.add_theme_color_override("font_color", TF.RED)
	dr.add_child(_delete_btn)
	add_child(dr)
	var info := TF.label("Saves and purchases are stored only on this device. Stellar Store items are kept when you delete an expedition.", 14, TF.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)


func _label(t: String) -> Label:
	var l := TF.label(t, 19)
	l.custom_minimum_size.x = 220
	return l


func _section(t: String, c: Color) -> void:
	if get_child_count() > 0:
		var sp := Control.new()
		sp.custom_minimum_size.y = 6
		add_child(sp)
	add_child(TF.label(t, 18, c))
	var line := ColorRect.new()
	line.color = Color(c.r, c.g, c.b, 0.35)
	line.custom_minimum_size.y = 2
	add_child(line)


func _row(label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(_label(label))
	add_child(h)
	return h


func _slider(key: String, label: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var h := _row(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings.get(key, lo))
	s.custom_minimum_size = Vector2(260, 44)
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
		Game.settings[key] = int(val) if key in ["render_distance", "fov"] else val
		v.text = fmt.call(val)
		Game.save_settings()
		changed.emit())
	_rows[key] = s
	_fmt[key] = [v, fmt]


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


func _sync_all() -> void:
	for k in _rows:
		var c = _rows[k]
		if c is HSlider:
			c.set_value_no_signal(float(Game.settings.get(k, c.min_value)))
			_fmt[k][0].text = _fmt[k][1].call(c.value)
		elif c is Button:
			c.set_pressed_no_signal(bool(Game.settings.get(k, false)))
			c.text = "ON" if c.button_pressed else "OFF"


func _preset(name: String) -> void:
	for k in PRESETS[name]:
		Game.settings[k] = PRESETS[name][k]
	Game.save_settings()
	_sync_all()
	changed.emit()


func _reset() -> void:
	Game.reset_settings()
	_sync_all()
	changed.emit()


func _delete_save() -> void:
	if not _confirm_delete:
		_confirm_delete = true
		_delete_btn.text = "Tap again to confirm"
		return
	Game.delete_save()
	_delete_btn.text = "Save deleted"
	_delete_btn.disabled = true


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

class_name Onboarding
extends Control
## First-run field guide. Three pages, shown once after the splash chain. Skippable.

signal closed(start_expedition: bool)

const TF := preload("res://scripts/ui/theme_factory.gd")

const PAGES := [
	{
		"kicker": "FIELD GUIDE · 1 OF 3",
		"title": "SURVIVE",
		"body": "Your crash pod is gone. Verdania is beautiful and hostile: watch oxygen, temperature and hunger, mine basalt, and put a roof over your head before the first night.",
		"hint": "Drag to look. Joystick to move. Hold MINE to cut blocks.",
		"accent": Color(1.0, 0.36, 0.4),
	},
	{
		"kicker": "FIELD GUIDE · 2 OF 3",
		"title": "BUILD · AUTOMATE",
		"body": "Place blocks, craft a fabricator, and raise solar-powered machines. Storage, miners and hydroponics keep working while you are away.",
		"hint": "Open the backpack to craft. Machines need power and a free tile.",
		"accent": Color(1.0, 0.69, 0.18),
	},
	{
		"kicker": "FIELD GUIDE · 3 OF 3",
		"title": "EXPLORE · EVOLVE",
		"body": "Tame creatures, assemble a starship and jump between six alien worlds. Then terraform dead ground into a living, breathing planet.",
		"hint": "Directives guide you. Stellar Shards unlock suits, lasers, rovers and ships.",
		"accent": Color(0.31, 0.89, 1.0),
	},
]

var _page := 0
var _card: PanelContainer
var _kicker: Label
var _title: Label
var _body: Label
var _hint: Label
var _art: PageArt
var _dots: HBoxContainer
var _back: Button
var _next: Button
var _skip: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = ThemeFactory.build()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.005, 0.04, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", TF.box(Color(0.03, 0.03, 0.085, 0.98), TF.LINE, 20, 2, 26))
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.anchor_left = 0.06
	_card.anchor_right = 0.94
	_card.anchor_top = 0.07
	_card.anchor_bottom = 0.93
	_card.offset_left = 0
	_card.offset_right = 0
	_card.offset_top = 0
	_card.offset_bottom = 0
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_kicker = TF.label("", 17, TF.AMBER)
	_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_kicker)
	_skip = TF.button("SKIP", _finish.bind(false), 130)
	_skip.custom_minimum_size.y = 48
	head.add_child(_skip)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	_art = PageArt.new()
	_art.custom_minimum_size = Vector2(330, 300)
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.size_flags_horizontal = Control.SIZE_FILL
	body.add_child(_art)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_title = TF.label("", 40, TF.CYAN)
	right.add_child(_title)
	_body = TF.label("", 21, TF.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_body)
	_hint = TF.label("", 16, TF.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_hint)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	v.add_child(_dots)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_back = TF.button("BACK", _step.bind(-1), 170)
	_back.custom_minimum_size.y = 58
	row.add_child(_back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next = TF.button("NEXT", _step.bind(1), 300)
	_next.custom_minimum_size.y = 60
	_next.add_theme_font_size_override("font_size", 24)
	_next.add_theme_stylebox_override("normal", TF.box(Color(0.1, 0.34, 0.3, 0.95), TF.GREEN, 12, 2, 16))
	_next.add_theme_stylebox_override("hover", TF.box(Color(0.15, 0.46, 0.38, 0.95), TF.GREEN, 12, 2, 16))
	row.add_child(_next)
	_show_page(0, false)
	await get_tree().process_frame
	UiAnim.pop_in(_card, 0.05, 0.94)


func _show_page(i: int, animate := true) -> void:
	_page = clampi(i, 0, PAGES.size() - 1)
	var p: Dictionary = PAGES[_page]
	_kicker.text = p["kicker"]
	_title.text = p["title"]
	_title.add_theme_color_override("font_color", p["accent"].lightened(0.15))
	_body.text = p["body"]
	_hint.text = p["hint"]
	_art.page = _page
	_art.accent = p["accent"]
	_back.disabled = _page == 0
	_next.text = "BEGIN EXPEDITION" if _page == PAGES.size() - 1 else "NEXT"
	for c in _dots.get_children():
		c.queue_free()
	for k in PAGES.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(26 if k == _page else 12, 4)
		d.color = p["accent"] if k == _page else Color(1, 1, 1, 0.22)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)
	if animate:
		_title.modulate.a = 0.0
		_body.modulate.a = 0.0
		var tw := _title.create_tween().set_parallel(true)
		tw.tween_property(_title, "modulate:a", 1.0, 0.2)
		tw.tween_property(_body, "modulate:a", 1.0, 0.3).set_delay(0.05)


func _step(delta: int) -> void:
	if _page >= PAGES.size() - 1 and delta > 0:
		_finish(true)
	else:
		_show_page(_page + delta)


func _finish(start_expedition: bool) -> void:
	Game.set_onboarded()
	var tw := _card.create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		closed.emit(start_expedition)
		queue_free())


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish(false)


class PageArt:
	extends Control
	var page := 0
	var accent := Color(0.31, 0.89, 1.0)
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		draw_style_box(
			ThemeFactory.box(Color(0.015, 0.02, 0.06, 0.9), Color(accent.r, accent.g, accent.b, 0.35), 18, 2, 0),
			Rect2(Vector2.ZERO, s)
		)
		for i in 16:
			var p := Vector2(fmod(i * 97.0, s.x - 20) + 10, fmod(i * 61.0, s.y - 20) + 10)
			draw_circle(p, 1.4 + (i % 3) * 0.5, Color(1, 1, 1, 0.18 + 0.12 * sin(t * 0.7 + i)))
		match page:
			0:
				_draw_survive(c)
			1:
				_draw_build(c)
			_:
				_draw_evolve(c)

	func _draw_survive(c: Vector2) -> void:
		var w := minf(size.x, size.y) * 0.62
		var top := c - Vector2(w * 0.5, w * 0.52)
		draw_rect(Rect2(top + Vector2(0, 0), Vector2(w, w * 0.16)), Color(1.0, 0.36, 0.4))
		draw_rect(Rect2(top + Vector2(0, w * 0.22), Vector2(w, w * 0.16)), Color(0.31, 0.89, 1.0))
		draw_rect(Rect2(top + Vector2(0, w * 0.44), Vector2(w * 0.72, w * 0.16)), Color(1.0, 0.69, 0.18))
		for i in 3:
			draw_rect(Rect2(top + Vector2(w * 0.78, w * 0.44 + i * w * 0.1), Vector2(w * 0.22, w * 0.06)), Color(1, 1, 1, 0.18))
		var base := c + Vector2(0, w * 0.42)
		for i in 4:
			var bw := w * (1.0 - i * 0.16)
			draw_rect(Rect2(base + Vector2(-bw * 0.5, i * w * 0.09), Vector2(bw, w * 0.09)), Color(0.18, 0.65, 0.58).darkened(i * 0.06))
		for i in 3:
			var x := -w * 0.34 + i * w * 0.2
			var h := w * (0.2 + 0.08 * i)
			var pts := PackedVector2Array([
				base + Vector2(x, -h), base + Vector2(x + w * 0.07, -h * 0.55),
				base + Vector2(x + w * 0.03, 0.0), base + Vector2(x - w * 0.06, 0.0),
			])
			draw_colored_polygon(pts, Color(0.35, 0.95, 0.85, 0.55 + 0.15 * sin(t * 2.0 + i)))
		draw_string(ThemeDB.fallback_font, top + Vector2(w * 0.12, w * 0.13), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.6))
		draw_string(ThemeDB.fallback_font, top + Vector2(w * 0.12, w * 0.35), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.6))

	func _draw_build(c: Vector2) -> void:
		var r := minf(size.x, size.y) * 0.22
		var box := Rect2(c - Vector2(r * 1.35, r * 0.7), Vector2(r * 2.7, r * 1.7))
		draw_rect(box, Color(0.24, 0.28, 0.36))
		draw_rect(Rect2(box.position, Vector2(box.size.x, r * 0.22)), Color(0.4, 0.46, 0.56))
		draw_rect(Rect2(box.position + Vector2(0, box.size.y - r * 0.18), Vector2(box.size.x, r * 0.18)), Color(1.0, 0.69, 0.18, 0.85))
		for i in 4:
			draw_rect(Rect2(box.position + Vector2(r * 0.3 + i * r * 0.35, r * 0.4), Vector2(r * 0.16, r * 0.16)), Color(0.2, 0.9, 0.7))
		var gear := c + Vector2(r * 1.25, -r * 1.0)
		var ang := t * 0.8
		for i in 8:
			var a := ang + i * TAU / 8.0
			draw_line(gear + Vector2.from_angle(a) * r * 0.42, gear + Vector2.from_angle(a) * r * 0.58, accent, 6.0, true)
		draw_circle(gear, r * 0.42, accent)
		draw_circle(gear, r * 0.2, Color(0.02, 0.03, 0.08))
		var panel := c + Vector2(-r * 1.6, -r * 1.65)
		for gx in 3:
			for gy in 2:
				draw_rect(Rect2(panel + Vector2(gx * r * 0.34, gy * r * 0.24), Vector2(r * 0.3, r * 0.2)), Color(0.1, 0.3, 0.55))
				draw_line(panel + Vector2(gx * r * 0.34, gy * r * 0.24), panel + Vector2(gx * r * 0.34 + r * 0.3, gy * r * 0.24 + r * 0.2), Color(0.35, 0.7, 1.0, 0.5), 1.0)

	func _draw_evolve(c: Vector2) -> void:
		var r := minf(size.x, size.y) * 0.3
		draw_circle(c + Vector2(0, -r * 0.12), r, Color(0.14, 0.52, 0.5))
		draw_circle(c + Vector2(-r * 0.22, -r * 0.3), r * 0.42, Color(0.25, 0.82, 0.7, 0.7))
		draw_circle(c + Vector2(r * 0.3, r * 0.1), r * 0.3, Color(0.08, 0.36, 0.38, 0.75))
		var tilt := -0.35
		for pass_i in 2:
			var pts := PackedVector2Array()
			for i in 65:
				var a := i / 64.0 * TAU
				var front := sin(a) > 0.0
				if front != (pass_i == 0):
					if pts.size() > 1:
						draw_polyline(pts, Color(1.0, 0.69, 0.18, 0.95 if pass_i == 0 else 0.45), 5.0, true)
					pts.clear()
					continue
				pts.append(c + Vector2(cos(a) * r * 1.7, sin(a) * r * 0.5).rotated(tilt + sin(t * 0.4) * 0.04))
			if pts.size() > 1:
				draw_polyline(pts, Color(1.0, 0.69, 0.18, 0.95 if pass_i == 0 else 0.45), 5.0, true)
		var lander := c + Vector2(r * 0.9, r * 1.15)
		draw_rect(Rect2(lander, Vector2(r * 0.5, r * 0.32)), Color(0.9, 0.55, 0.2))
		draw_colored_polygon(PackedVector2Array([lander + Vector2(0, -r * 0.22), lander + Vector2(r * 0.28, 0), lander + Vector2(-r * 0.08, 0)]), Color(0.95, 0.75, 0.35))
		draw_line(lander + Vector2(r * 0.7, -r * 0.1), lander + Vector2(r * 0.7, r * 0.32), Color(1, 1, 1, 0.4), 2.0)
		draw_circle(lander + Vector2(r * 0.7, -r * 0.13), 3.0 + sin(t * 4.0), Color(1.0, 0.3, 0.2))

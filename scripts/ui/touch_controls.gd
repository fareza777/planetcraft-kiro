class_name TouchControls
extends Control
## Multitouch controls: floating joystick (left), drag-to-look (right), tap = use/place,
## long-press = mine, plus custom-drawn buttons. Drawn in one node.

signal button_pressed(name: String)

const TF := preload("res://scripts/ui/theme_factory.gd")
const JOY_R := 90.0

var player: Player
var hud: Hud
var sensitivity := 1.0
var enabled := true

var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _look_start := Vector2.ZERO
var _look_last := Vector2.ZERO
var _look_time := 0.0
var _look_moved := 0.0
var _long_mine := false
var _buttons := {}        # name -> {pos, r, label, hold}
var _btn_touch := {}      # touch index -> button name
var _held := {}           # button name -> true
var sprint_toggle := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var k := float(Game.settings.get("button_scale", 1.0))
	_buttons = {
		"jump": {"pos": Vector2(w - 110 * k, h - 150 * k), "r": 62.0 * k, "label": "JUMP", "icon": "jump", "col": Color(0.31, 0.89, 1.0)},
		"mine": {"pos": Vector2(w - 250 * k, h - 105 * k), "r": 56.0 * k, "label": "MINE", "icon": "mine", "col": Color(1.0, 0.69, 0.18)},
		"use": {"pos": Vector2(w - 125 * k, h - 305 * k), "r": 50.0 * k, "label": "USE", "icon": "use", "col": Color(0.48, 1.0, 0.6)},
		"sprint": {"pos": Vector2(w - 265 * k, h - 250 * k), "r": 40.0 * k, "label": "RUN", "icon": "run", "col": Color(0.85, 0.75, 1.0)},
		"inv": {"pos": Vector2(w - 150, 50), "r": 36.0, "label": "", "icon": "bag", "col": Color(0.31, 0.89, 1.0)},
		"menu": {"pos": Vector2(w - 60, 50), "r": 36.0, "label": "", "icon": "pause", "col": Color(0.9, 0.95, 1.0)},
	}


func reset() -> void:
	_joy_index = -1
	_look_index = -1
	_btn_touch.clear()
	_held.clear()
	_long_mine = false
	if player:
		player.ctl.move = Vector2.ZERO
		player.ctl.jump = false
		player.ctl.mine = false


func _button_at(p: Vector2) -> String:
	for n in _buttons:
		var b: Dictionary = _buttons[n]
		if p.distance_to(b.pos) <= b.r + 12.0:
			return n
	return ""


func _input(event: InputEvent) -> void:
	if not enabled or player == null or not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var pos := e.position
		if e.pressed:
			var bn := _button_at(pos)
			if bn != "":
				_btn_touch[e.index] = bn
				_held[bn] = true
				_on_button(bn, true)
			elif hud != null and hud.slot_at(pos) >= 0:
				player.selected = hud.slot_at(pos)
			elif pos.x < size.x * 0.42 and _joy_index < 0:
				_joy_index = e.index
				_joy_origin = pos
				_joy_pos = pos
			elif _look_index < 0:
				_look_index = e.index
				_look_start = pos
				_look_last = pos
				_look_time = 0.0
				_look_moved = 0.0
				_long_mine = false
		else:
			if _btn_touch.has(e.index):
				var bn: String = _btn_touch[e.index]
				_btn_touch.erase(e.index)
				_held.erase(bn)
				_on_button(bn, false)
			elif e.index == _joy_index:
				_joy_index = -1
				player.ctl.move = Vector2.ZERO
			elif e.index == _look_index:
				if not _long_mine and _look_time < 0.3 and _look_moved < 18.0:
					player.ctl.place = true
				if _long_mine:
					player.ctl.mine = _held.has("mine")
				_look_index = -1
				_long_mine = false
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_index:
			_joy_pos = d.position
			var v := (_joy_pos - _joy_origin) / JOY_R
			if v.length() > 1.0:
				_joy_origin = _joy_pos - v.normalized() * JOY_R
				v = v.normalized()
			player.ctl.move = Vector2(v.x, -v.y)
		elif d.index == _look_index:
			var delta := d.position - _look_last
			_look_last = d.position
			_look_moved += delta.length()
			if Game.settings.get("invert_y", false):
				delta.y = -delta.y
			player.ctl.look += delta * 0.0042 * sensitivity
		get_viewport().set_input_as_handled()


func _on_button(n: String, down: bool) -> void:
	match n:
		"jump":
			player.ctl.jump = down
		"mine":
			player.ctl.mine = down or _long_mine
		"use":
			if down:
				player.ctl.place = true
		"sprint":
			if down:
				sprint_toggle = not sprint_toggle
				player.ctl.sprint = sprint_toggle
		_:
			if down:
				button_pressed.emit(n)


func _process(dt: float) -> void:
	if _look_index >= 0:
		_look_time += dt
		if not _long_mine and _look_time > 0.38 and _look_moved < 22.0:
			_long_mine = true
			player.ctl.mine = true
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var font := ThemeDB.fallback_font
	if _joy_index >= 0:
		draw_circle(_joy_origin, JOY_R, Color(0.05, 0.05, 0.12, 0.35))
		draw_arc(_joy_origin, JOY_R, 0, TAU, 48, Color(0.31, 0.89, 1.0, 0.5), 3.0, true)
		draw_circle(_joy_pos, 38, Color(0.31, 0.89, 1.0, 0.55))
	else:
		var hint := Vector2(170, size.y - 170)
		draw_arc(hint, JOY_R * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0, true)
		draw_circle(hint, 26, Color(1, 1, 1, 0.1))
	var t := Time.get_ticks_msec() / 1000.0
	for n in _buttons:
		var b: Dictionary = _buttons[n]
		var held: bool = _held.has(n) or (n == "sprint" and sprint_toggle) or (n == "mine" and _long_mine)
		var col: Color = b.col
		var r: float = b.r * (0.92 if held else 1.0)
		draw_circle(b.pos + Vector2(0, 3), r, Color(0, 0, 0, 0.25))
		draw_circle(b.pos, r, Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.55) if held else Color(0.03, 0.03, 0.09, 0.5))
		draw_arc(b.pos, r - 1.5, 0, TAU, 48, Color(col.r, col.g, col.b, 0.95 if held else 0.55), 3.0, true)
		if held:
			draw_arc(b.pos, r + 5.0 + sin(t * 10.0) * 1.5, 0, TAU, 48, Color(col.r, col.g, col.b, 0.35), 2.0, true)
		var label: String = b.label
		var icon_y := -r * 0.12 if label != "" else 0.0
		IconPainter.draw(self, b.icon, b.pos + Vector2(0, icon_y), r * (0.5 if label != "" else 0.62), Color(1, 1, 1, 0.95) if held else col.lightened(0.25))
		if label != "":
			var fs := int(clampf(r * 0.24, 11, 16))
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, b.pos + Vector2(-tw * 0.5, r * 0.62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.75))

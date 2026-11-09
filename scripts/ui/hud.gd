class_name Hud
extends Control
## In-game HUD, drawn with immediate 2D calls (cheap on mobile, one node).

const SLOT := 70.0
const GAP := 6.0
const TF := preload("res://scripts/ui/theme_factory.gd")

var player: Player
var sky: SkyController
var info := {"planet": "", "biome": "", "fps": 0, "show_fps": true, "quest": "", "extra": "", "driving": false, "waypoint": null, "wp_label": ""}
var _story_speaker := ""
var _story_text := ""
var _story_t := 0.0
var toasts: Array = []
var damage_flash := 0.0
var _last_hp := 100.0
var font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func toast(text: String, color := TF.TEXT) -> void:
	toasts.push_front({"t": text, "c": color, "time": 3.5})
	if toasts.size() > 5:
		toasts.pop_back()


func story(speaker: String, text: String) -> void:
	_story_speaker = speaker
	_story_text = text
	_story_t = 0.0


func hotbar_rect() -> Rect2:
	var w := SLOT * 9 + GAP * 8
	return Rect2((size.x - w) * 0.5, size.y - SLOT - 14.0, w, SLOT)


func slot_at(pos: Vector2) -> int:
	var r := hotbar_rect()
	if not r.grow(6).has_point(pos):
		return -1
	var i := int((pos.x - r.position.x) / (SLOT + GAP))
	return clampi(i, 0, 8)


func _process(dt: float) -> void:
	for t in toasts:
		t.time -= dt
	toasts = toasts.filter(func(t: Dictionary) -> bool: return t.time > 0.0)
	if player != null:
		if player.stats.hp < _last_hp - 0.5:
			damage_flash = 1.0
		_last_hp = player.stats.hp
	damage_flash = maxf(0.0, damage_flash - dt * 2.0)
	if _story_text != "":
		_story_t += dt
		if _story_t > 4.0 + _story_text.length() * 0.05:
			_story_text = ""
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var st := player.stats
	# underwater / damage overlays
	if player.head_in_fluid:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.25, 0.5, 0.35))
	if damage_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.05, 0.1, damage_flash * 0.25))
	if st.hp < 25.0:
		var pulse := 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.0, 0.05, pulse))
	# stats panel
	var px := 18.0
	var py := 16.0
	draw_style_box(TF.box(TF.BG, TF.LINE, 12), Rect2(px - 8, py - 8, 318, 168))
	_bar(px, py, "heart", st.hp, st.max_hp, Color(1.0, 0.33, 0.4))
	_bar(px, py + 30, "o2", st.o2, st.max_o2, Color(0.31, 0.89, 1.0))
	_bar(px, py + 60, "bolt", st.energy, st.max_energy, Color(1.0, 0.82, 0.25))
	_bar(px, py + 90, "food", st.food, 100.0, Color(0.5, 0.95, 0.45))
	var tcol := TF.TEXT
	if st.body_temp < -10.0:
		tcol = Color(0.6, 0.85, 1.0)
	elif st.body_temp > 40.0:
		tcol = Color(1.0, 0.55, 0.3)
	IconPainter.draw(self, "temp", Vector2(px + 8, py + 133), 11.0, tcol)
	_text(Vector2(px + 20, py + 140), "%+.0f°C" % st.body_temp, 18, tcol)
	IconPainter.draw(self, "rad", Vector2(px + 108, py + 134), 10.0, Color(0.7, 1.0, 0.3) if st.rad > 5.0 else TF.DIM)
	_text(Vector2(px + 122, py + 140), "%d%%" % int(st.rad), 18, Color(0.7, 1.0, 0.3) if st.rad > 5.0 else TF.DIM)
	IconPainter.draw(self, "xp", Vector2(px + 196, py + 134), 10.0, TF.AMBER)
	_text(Vector2(px + 210, py + 140), "%d" % player.xp, 18, TF.AMBER)
	# top center info
	var title := "%s  ·  %s  ·  %s" % [info.planet, info.biome, sky.clock_text() if sky else ""]
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_style_box(TF.box(TF.BG, TF.LINE, 10), Rect2((size.x - tw) * 0.5 - 16, 10, tw + 32, 40))
	_text(Vector2((size.x - tw) * 0.5, 37), title, 20, TF.TEXT)
	var p := player.global_position
	var coords := "X %d  Y %d  Z %d" % [floori(p.x), floori(p.y), floori(p.z)]
	var cw := font.get_string_size(coords, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(Vector2((size.x - cw) * 0.5, 70), coords, 16, TF.DIM)
	if info.quest != "":
		var qw := font.get_string_size(info.quest, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_style_box(TF.box(Color(0.08, 0.06, 0.02, 0.75), Color(1, 0.69, 0.18, 0.5), 8), Rect2(px - 8, 190, qw + 26, 34))
		_text(Vector2(px + 4, 213), info.quest, 17, TF.AMBER)
	if info.show_fps:
		_text(Vector2(size.x - 330, 30), "%d FPS" % info.fps, 18, TF.GREEN if info.fps >= 30 else TF.RED)
	if info.extra != "":
		_text(Vector2(size.x - 330, 52), info.extra, 14, TF.DIM)
	# warning
	if st.warning != "" and int(Time.get_ticks_msec() / 400) % 2 == 0:
		var ww := font.get_string_size(st.warning, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		_text(Vector2((size.x - ww) * 0.5, size.y * 0.3), st.warning, 30, TF.RED)
	_draw_waypoint()
	_draw_story()
	if info.driving:
		var dt := "ROVER  ·  JUMP to exit  ·  drag right side to look around"
		var dw := font.get_string_size(dt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_text(Vector2((size.x - dw) * 0.5, size.y - 30), dt, 18, TF.AMBER)
		_draw_toasts(size.y - 60)
		return
	# crosshair
	var c := size * 0.5
	var cc := Color(1, 1, 1, 0.85)
	draw_rect(Rect2(c.x - 11, c.y - 1.5, 8, 3), cc)
	draw_rect(Rect2(c.x + 3, c.y - 1.5, 8, 3), cc)
	draw_rect(Rect2(c.x - 1.5, c.y - 11, 3, 8), cc)
	draw_rect(Rect2(c.x - 1.5, c.y + 3, 3, 8), cc)
	if player.mine_progress > 0.0:
		draw_arc(c, 20, -PI / 2, -PI / 2 + TAU * clampf(player.mine_progress, 0, 1), 32, TF.CYAN, 4.0, true)
	if not player.target.is_empty():
		var name: String = Reg.block_def(player.target.id).get("label", "")
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_text(Vector2(c.x - nw * 0.5, c.y + 44), name, 16, Color(1, 1, 1, 0.8))
	# hotbar
	var hr := hotbar_rect()
	draw_style_box(TF.box(TF.BG, TF.LINE, 12, 2, 0), hr.grow(8))
	for i in 9:
		var r := Rect2(hr.position.x + i * (SLOT + GAP), hr.position.y, SLOT, SLOT)
		var sel := i == player.selected
		draw_style_box(TF.box(Color(0.15, 0.3, 0.42, 0.9) if sel else Color(0.06, 0.07, 0.14, 0.9), TF.AMBER if sel else Color(1, 1, 1, 0.1), 8, 3 if sel else 1, 0), r)
		var s = player.inv.slots[i]
		if s != null:
			draw_texture_rect(Reg.icon(s.id), r.grow(-9), false)
			if s.n > 1:
				_text(r.position + Vector2(SLOT - 10 - font.get_string_size(str(s.n), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, SLOT - 8), str(s.n), 18, Color.WHITE)
	var sel_s = player.inv.slots[player.selected]
	if sel_s != null:
		var lbl := Reg.item_label(sel_s.id)
		var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_text(Vector2((size.x - lw) * 0.5, hr.position.y - 18), lbl, 18, TF.TEXT)
	_draw_toasts(hr.position.y - 52)


func _draw_toasts(start_y: float) -> void:
	var ty := start_y
	for t in toasts:
		var a := clampf(t.time, 0.0, 1.0)
		var col: Color = t.c
		col.a = a
		var w := font.get_string_size(t.t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var bg := TF.BG
		bg.a *= a
		draw_style_box(TF.box(bg, Color(col.r, col.g, col.b, 0.4 * a), 8), Rect2((size.x - w) * 0.5 - 12, ty - 24, w + 24, 32))
		_text(Vector2((size.x - w) * 0.5, ty - 2), t.t, 20, col)
		ty -= 38


func _draw_waypoint() -> void:
	if info.waypoint == null or player.cam == null:
		return
	var wp: Vector3 = info.waypoint
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var behind := cam.is_position_behind(wp)
	var sp := cam.unproject_position(wp)
	if behind:
		sp = size - sp
	var m := 60.0
	var on := sp.x > m and sp.x < size.x - m and sp.y > m and sp.y < size.y - m and not behind
	var c := size * 0.5
	if not on:
		var d := (sp - c).normalized()
		var k := minf((size.x * 0.5 - m) / maxf(absf(d.x), 0.001), (size.y * 0.5 - m) / maxf(absf(d.y), 0.001))
		sp = c + d * k
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
	var r := 13.0 * pulse
	var col := TF.AMBER
	draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -r), sp + Vector2(r, 0), sp + Vector2(0, r), sp + Vector2(-r, 0)]), Color(col.r, col.g, col.b, 0.9))
	draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -r * 0.5), sp + Vector2(r * 0.5, 0), sp + Vector2(0, r * 0.5), sp + Vector2(-r * 0.5, 0)]), Color(0, 0, 0, 0.5))
	var dist := int(player.global_position.distance_to(wp))
	var t := "%s · %d m" % [info.wp_label, dist]
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(sp + Vector2(-tw * 0.5, r + 20), t, 16, col)


func _draw_story() -> void:
	if _story_text == "":
		return
	var a := clampf(_story_t * 3.0, 0.0, 1.0) * clampf((4.0 + _story_text.length() * 0.05) - _story_t, 0.0, 1.0)
	var shown := _story_text.substr(0, int(_story_t * 45.0))
	var w := minf(size.x * 0.62, 900.0)
	var lines := font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, w - 40, 19)
	var h := maxf(lines.y, 24) + 52
	var r := Rect2((size.x - w) * 0.5, size.y * 0.16, w, h)
	draw_style_box(TF.box(Color(0.02, 0.03, 0.08, 0.82 * a), Color(0.31, 0.89, 1.0, 0.5 * a), 12, 2, 0), r)
	draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(5, r.size.y)), Color(0.31, 0.89, 1.0, a))
	_text(r.position + Vector2(20, 28), _story_speaker.to_upper(), 16, Color(TF.AMBER.r, TF.AMBER.g, TF.AMBER.b, a))
	draw_multiline_string(font, r.position + Vector2(20, 54), shown, HORIZONTAL_ALIGNMENT_LEFT, w - 40, 19, -1, Color(0.9, 0.95, 1.0, a))


func _bar(x: float, y: float, label: String, v: float, mx: float, col: Color) -> void:
	IconPainter.draw(self, label, Vector2(x + 13, y + 13), 12.0, col)
	var r := Rect2(x + 36, y + 4, 210, 18)
	draw_rect(r, Color(0, 0, 0, 0.55))
	var f := clampf(v / maxf(mx, 0.001), 0.0, 1.0)
	var c := col
	if f < 0.2 and int(Time.get_ticks_msec() / 300) % 2 == 0:
		c = c.lightened(0.4)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), c)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, 4)), Color(1, 1, 1, 0.25))
	_text(Vector2(x + 254, y + 19), str(int(v)), 16, TF.TEXT)


func _text(pos: Vector2, s: String, sz: int, c: Color) -> void:
	draw_string(font, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, c.a * 0.7))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

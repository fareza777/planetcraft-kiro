class_name MapScreen
extends Control
## Revealed Planetary Map with discovered POIs and custom waypoint placement.

signal closed
signal waypoint_set(pos: Variant)

const TF := preload("res://scripts/ui/theme_factory.gd")

var world_root: Node
var _panel: PanelContainer
var _canvas: Control
var _zoom := 1.4
var _center := Vector2.ZERO
var _info_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", TF.box(Color(0.03, 0.04, 0.09, 0.96), TF.LINE, 18, 2, 16))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	v.add_child(bar)
	var title := TF.label("PLANETARY SURVEY MAP", 22, TF.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	bar.add_child(TF.button("Clear Pin", _clear_pin, 120))
	bar.add_child(TF.button("+", func() -> void: _zoom = clampf(_zoom * 1.35, 0.5, 4.0); _canvas.queue_redraw(), 52))
	bar.add_child(TF.button("-", func() -> void: _zoom = clampf(_zoom / 1.35, 0.5, 4.0); _canvas.queue_redraw(), 52))
	bar.add_child(TF.button("✕", _close, 60))
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_map_input)
	v.add_child(_canvas)
	_info_lbl = TF.label("Tap anywhere on the map to set a custom HUD waypoint. Discovered structures & outposts appear automatically.", 15, TF.DIM)
	v.add_child(_info_lbl)
	resized.connect(_layout)


func _layout() -> void:
	if _panel == null:
		return
	var m := Vector2(clampf(size.x * 0.05, 20, 70), clampf(size.y * 0.06, 16, 50))
	_panel.position = m
	_panel.size = size - m * 2.0


func open(wr: Node) -> void:
	world_root = wr
	var pp: Vector3 = wr.player.global_position
	_center = Vector2(pp.x, pp.z)
	visible = true
	_layout()
	_canvas.queue_redraw()
	UiAnim.pop_in(_panel, 0.0, 0.94)


func _clear_pin() -> void:
	waypoint_set.emit(null)
	_canvas.queue_redraw()


func _close() -> void:
	visible = false
	closed.emit()


func _on_map_input(event: InputEvent) -> void:
	var clicked := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		clicked = true
		pos = event.position
	if not clicked or world_root == null:
		return
	var c := _canvas.size * 0.5
	var wp2 := _center + (pos - c) / _zoom
	var wx := floori(wp2.x)
	var wz := floori(wp2.y)
	var wy: int = int(world_root.world.column_top(wx, wz))
	if wy <= 0:
		wy = int(world_root.player.global_position.y)
	waypoint_set.emit(Vector3(wx + 0.5, wy + 2.0, wz + 0.5))
	_info_lbl.text = "Custom waypoint set at X %d, Z %d" % [wx, wz]
	_canvas.queue_redraw()


func _draw_map() -> void:
	if world_root == null:
		return
	var s := _canvas.size
	var c := s * 0.5
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.06, 1.0))
	# subtle grid
	var step := 32.0 * _zoom
	var gx := fposmod(c.x - _center.x * _zoom, step)
	while gx < s.x:
		_canvas.draw_line(Vector2(gx, 0), Vector2(gx, s.y), Color(1, 1, 1, 0.05), 1.0)
		gx += step
	var gy := fposmod(c.y - _center.y * _zoom, step)
	while gy < s.y:
		_canvas.draw_line(Vector2(0, gy), Vector2(s.x, gy), Color(1, 1, 1, 0.05), 1.0)
		gy += step
	# explored chunks
	var explored: Dictionary = world_root.explored_chunks
	var tile := 16.0 * _zoom
	for key in explored:
		var ck: Vector2i = key
		var col: Color = explored[key]
		var sp := c + (Vector2(ck.x * 16.0, ck.y * 16.0) - _center) * _zoom
		var r := Rect2(sp, Vector2(tile + 0.5, tile + 0.5))
		if r.intersects(Rect2(Vector2.ZERO, s)):
			_canvas.draw_rect(r, col)
	# discovered POIs
	for poi in world_root.discovered_pois.values():
		var p3: Vector3 = poi.pos
		var sp := c + (Vector2(p3.x, p3.z) - _center) * _zoom
		var col: Color = poi.col
		_canvas.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -8), sp + Vector2(8, 0), sp + Vector2(0, 8), sp + Vector2(-8, 0)]), col)
		_canvas.draw_string(font, sp + Vector2(11, 5), String(poi.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	# custom waypoint
	if world_root.custom_waypoint != null:
		var wp: Vector3 = world_root.custom_waypoint
		var sp := c + (Vector2(wp.x, wp.z) - _center) * _zoom
		_canvas.draw_arc(sp, 11.0, 0, TAU, 24, TF.AMBER, 2.5, true)
		_canvas.draw_circle(sp, 4.0, TF.AMBER)
		_canvas.draw_string(font, sp + Vector2(14, 5), "CUSTOM PIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TF.AMBER)
	# player arrow
	var pp: Vector3 = world_root.player.global_position
	var psp := c + (Vector2(pp.x, pp.z) - _center) * _zoom
	var fwd := Vector2(-sin(world_root.player.yaw), -cos(world_root.player.yaw))
	var rgt := Vector2(-fwd.y, fwd.x)
	_canvas.draw_colored_polygon(PackedVector2Array([psp + fwd * 11.0, psp - fwd * 7.0 + rgt * 6.0, psp - fwd * 4.0, psp - fwd * 7.0 - rgt * 6.0]), Color.WHITE)
	_canvas.draw_string(font, Vector2(12, 22), "N ↑   ·   Explored chunks: %d   ·   POIs: %d" % [explored.size(), world_root.discovered_pois.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TF.CYAN)

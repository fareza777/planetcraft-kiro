class_name SlotView
extends Control
## Custom-drawn inventory slot: icon, stack count, category tint, selection glow.
## Cheap to update (no child nodes, no stylebox overrides).

signal tapped(index: int)

const TF := preload("res://scripts/ui/theme_factory.gd")

var index := 0
var item_id := ""
var count := 0
var selected := false
var hotbar := false
var dim := false
var _press := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_item(id: String, n: int) -> void:
	if id == item_id and n == count:
		return
	item_id = id
	count = n
	queue_redraw()


func set_selected(v: bool) -> void:
	if v != selected:
		selected = v
		queue_redraw()


static func category_color(id: String) -> Color:
	if id == "":
		return Color(1, 1, 1, 0.08)
	var it := Reg.item(id)
	match it.get("type", ""):
		"tool", "weapon": return Color(1.0, 0.69, 0.18)
		"upgrade": return Color(0.75, 0.5, 1.0)
		"ship_part", "deploy": return Color(1.0, 0.45, 0.8)
		"food", "consumable": return Color(0.48, 1.0, 0.6)
		"research": return Color(0.31, 0.89, 1.0)
		"block":
			return Color(0.31, 0.89, 1.0) if Reg.block_def(int(it.block)).has("machine") or Reg.block_def(int(it.block)).has("station") else Color(0.7, 0.75, 0.9)
	return Color(0.7, 0.75, 0.9)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = 1.0
			queue_redraw()
		else:
			_press = 0.0
			queue_redraw()
			if Rect2(Vector2.ZERO, size).has_point(e.position):
				tapped.emit(index)
				accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var cat := category_color(item_id)
	var bg := Color(0.06, 0.07, 0.15, 0.94) if not hotbar else Color(0.08, 0.1, 0.2, 0.96)
	if item_id != "":
		bg = bg.lerp(Color(cat.r, cat.g, cat.b, 0.95), 0.12)
	if _press > 0.0:
		bg = bg.lightened(0.15)
	var border := cat
	border.a = 0.55 if item_id != "" else 0.12
	if selected:
		border = TF.AMBER
		draw_style_box(TF.box(Color(1, 0.69, 0.18, 0.18), Color(0, 0, 0, 0), 12, 0, 0), r.grow(4))
	draw_style_box(TF.box(bg, border, 10, 3 if selected else 2, 0), r)
	if hotbar:
		draw_rect(Rect2(r.position + Vector2(6, r.size.y - 5), Vector2(r.size.x - 12, 2)), Color(0.31, 0.89, 1.0, 0.35))
	if item_id != "":
		var pad := r.size.x * (0.16 if _press == 0.0 else 0.2)
		draw_texture_rect(Reg.icon(item_id), r.grow(-pad), false, Color(1, 1, 1, 0.45) if dim else Color.WHITE)
		if count > 1:
			var font := ThemeDB.fallback_font
			var fs := int(clampf(size.x * 0.26, 13, 22))
			var s := str(count)
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := Vector2(size.x - w - 6, size.y - 6)
			draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
			draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	elif hotbar:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(7, 18), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.25))

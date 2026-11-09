class_name ThemeFactory
extends RefCounted
## Builds the PlanetCraft UI theme in code: dark translucent glass panels with cyan and
## amber accents. No external fonts or images.

const BG := Color(0.035, 0.03, 0.09, 0.86)
const BG2 := Color(0.07, 0.07, 0.16, 0.92)
const LINE := Color(0.31, 0.89, 1.0, 0.45)
const CYAN := Color(0.31, 0.89, 1.0)
const AMBER := Color(1.0, 0.69, 0.18)
const TEXT := Color(0.9, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.8)
const RED := Color(1.0, 0.36, 0.4)
const GREEN := Color(0.48, 1.0, 0.6)


static func box(bg: Color, border: Color, radius := 10, bw := 2, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("panel", "Panel", box(BG, LINE, 14))
	t.set_stylebox("panel", "PanelContainer", box(BG, LINE, 14, 2, 14))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.12, 0.24, 0.95), LINE, 10, 2, 14))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.2, 0.34, 0.95), CYAN, 10, 2, 14))
	t.set_stylebox("pressed", "Button", box(Color(0.2, 0.42, 0.55, 0.95), CYAN, 10, 2, 14))
	t.set_stylebox("disabled", "Button", box(Color(0.08, 0.08, 0.14, 0.8), Color(0.3, 0.3, 0.4, 0.4), 10, 2, 14))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), AMBER, 10, 2, 14))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.52, 0.6))
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.12), 6, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(CYAN, Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("normal", "LineEdit", box(Color(0.05, 0.06, 0.12, 0.95), LINE, 8, 2, 10))
	t.set_stylebox("focus", "LineEdit", box(Color(0.05, 0.06, 0.12, 0.95), CYAN, 8, 2, 10))
	t.set_stylebox("panel", "TooltipPanel", box(BG2, LINE, 8))
	t.set_stylebox("grabber_area", "HSlider", box(CYAN, Color(0, 0, 0, 0), 4, 0, 0))
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.5), LINE, 4, 1, 0))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_stylebox("tab_selected", "TabBar", box(Color(0.2, 0.42, 0.55, 0.95), CYAN, 8, 2, 12))
	t.set_stylebox("tab_unselected", "TabBar", box(Color(0.1, 0.12, 0.24, 0.95), LINE, 8, 2, 12))
	t.set_stylebox("tab_hovered", "TabBar", box(Color(0.14, 0.2, 0.34, 0.95), CYAN, 8, 2, 12))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 4, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(0.31, 0.89, 1.0, 0.5), Color(0, 0, 0, 0), 4, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(CYAN, Color(0, 0, 0, 0), 4, 0, 0))
	return t


static func bar_fill(c: Color) -> StyleBoxFlat:
	return box(c, Color(0, 0, 0, 0), 6, 0, 0)


static func label(text: String, size := 20, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, min_w := 220) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 56)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b

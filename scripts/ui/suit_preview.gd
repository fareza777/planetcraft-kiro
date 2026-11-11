class_name SuitPreview
extends Control
## Animated full-body exosuit portrait drawn from a store definition: fabric pattern texture,
## helmet shape, visor style, accessory (antenna, fins, spikes, horns, leaves, halo) and a
## thruster trail. Used by the Stellar Store and the Suit tab.

const TF := preload("res://scripts/ui/theme_factory.gd")
static var _tex_cache := {}

var def: Dictionary = {}
var t := randf() * 10.0
var _tex: Texture2D


func set_def(d: Dictionary) -> void:
	def = d
	var key: String = d.get("id", "x")
	if not _tex_cache.has(key):
		var cols := []
		for c in d.get("colors", ["#3b4358", "#ffb02e", "#4fe3ff"]):
			cols.append(Color.html(c))
		var tf = load("res://scripts/voxel/texture_factory.gd")
		var img: Image = tf.make_suit(d.get("pattern", "stripes"), cols, hash(key))
		_tex_cache[key] = ImageTexture.create_from_image(img)
	_tex = _tex_cache[key]
	queue_redraw()


static func texture_for(d: Dictionary) -> Texture2D:
	var p := SuitPreview.new()
	p.set_def(d)
	var tex := p._tex
	p.free()
	return tex


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _col(i: int) -> Color:
	var cs: Array = def.get("colors", ["#3b4358", "#ffb02e", "#4fe3ff"])
	return Color.html(cs[mini(i, cs.size() - 1)])


func _draw() -> void:
	if def.is_empty():
		return
	var s := size
	draw_style_box(TF.box(Color(0.02, 0.02, 0.06, 1), Color(1, 1, 1, 0.06), 10, 1, 0), Rect2(Vector2.ZERO, s))
	var base := _col(0)
	var acc := _col(1)
	var glow := _col(2)
	var u := minf(s.x / 5.0, s.y / 7.4)
	var bob := sin(t * 1.8) * u * 0.06
	var c := Vector2(s.x * 0.5, s.y * 0.56 + bob)
	# floor glow + thruster trail
	var trail := Color.html(def.get("trail", "#ffb02e"))
	for k in 4:
		draw_rect(Rect2(c.x - u * (1.6 - k * 0.3), c.y + u * 3.0 + k * 1.5, u * (3.2 - k * 0.6), 3.0), Color(trail.r, trail.g, trail.b, 0.1 + k * 0.05))
	for k in 5:
		var f := fmod(t * 2.0 + k * 0.2, 1.0)
		draw_circle(c + Vector2(-u * 0.9 + sin(k * 3.1) * u * 0.1, u * 1.2 + f * u * 1.6), u * 0.22 * (1.0 - f), Color(trail.r, trail.g, trail.b, 0.6 * (1.0 - f)))
	# jetpack
	draw_rect(Rect2(c + Vector2(-u * 1.25, -u * 1.0), Vector2(u * 0.5, u * 1.9)), base.darkened(0.4))
	# legs
	for side in [-1, 1]:
		var lx: float = c.x + side * u * 0.42 - u * 0.33
		draw_texture_rect(_tex, Rect2(lx, c.y + u * 0.9, u * 0.66, u * 1.9), true)
		draw_rect(Rect2(lx - u * 0.04, c.y + u * 2.6, u * 0.74, u * 0.42), acc.darkened(0.35))
	# torso (patterned)
	var torso := Rect2(c + Vector2(-u * 1.05, -u * 1.2), Vector2(u * 2.1, u * 2.25))
	draw_texture_rect(_tex, torso, true)
	draw_rect(Rect2(torso.position + Vector2(0, torso.size.y - u * 0.3), Vector2(torso.size.x, u * 0.3)), acc.darkened(0.2))
	draw_rect(Rect2(c + Vector2(-u * 0.32, -u * 0.6), Vector2(u * 0.64, u * 0.5)), base.darkened(0.5))
	draw_rect(Rect2(c + Vector2(-u * 0.22, -u * 0.5), Vector2(u * 0.44, u * 0.12)), glow * (0.8 + 0.3 * sin(t * 4.0)))
	# arms
	var swing := sin(t * 1.8) * 0.06
	for side in [-1, 1]:
		var ax: float = c.x + side * u * 1.35 - u * 0.3
		draw_set_transform(Vector2(ax + u * 0.3, c.y - u * 1.0), side * swing, Vector2.ONE)
		draw_texture_rect(_tex, Rect2(-u * 0.3, 0, u * 0.6, u * 1.7), true)
		draw_rect(Rect2(-u * 0.34, u * 1.55, u * 0.68, u * 0.42), acc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# shoulders
	for side in [-1, 1]:
		draw_rect(Rect2(c + Vector2(side * u * 1.0 - u * 0.45, -u * 1.35), Vector2(u * 0.9, u * 0.4)), acc)
	_draw_helmet(c + Vector2(0, -u * 2.1), u, base, acc, glow)
	_draw_accessory(c, u, base, acc, glow)


func _draw_helmet(h: Vector2, u: float, base: Color, acc: Color, glow: Color) -> void:
	var shell := base.lightened(0.15)
	match def.get("helmet", "round"):
		"round":
			draw_circle(h, u * 0.95, shell)
		"dome":
			draw_circle(h, u * 1.0, Color(glow.r, glow.g, glow.b, 0.25))
			draw_circle(h, u * 0.85, shell)
		"angular":
			draw_colored_polygon(PackedVector2Array([h + Vector2(-u * 0.9, u * 0.6), h + Vector2(-u * 0.95, -u * 0.4), h + Vector2(0, -u * 1.05), h + Vector2(u * 0.95, -u * 0.4), h + Vector2(u * 0.9, u * 0.6)]), shell)
		"knight":
			draw_rect(Rect2(h + Vector2(-u * 0.85, -u * 0.9), Vector2(u * 1.7, u * 1.6)), shell)
			draw_rect(Rect2(h + Vector2(-u * 0.1, -u * 1.05), Vector2(u * 0.2, u * 0.4)), acc)
		"hood":
			draw_colored_polygon(PackedVector2Array([h + Vector2(-u * 1.05, u * 0.7), h + Vector2(-u * 0.8, -u * 0.6), h + Vector2(0, -u * 1.15), h + Vector2(u * 0.8, -u * 0.6), h + Vector2(u * 1.05, u * 0.7)]), acc.darkened(0.3))
			draw_circle(h + Vector2(0, u * 0.05), u * 0.72, shell)
		"crown":
			draw_circle(h, u * 0.9, shell)
			for k in 5:
				var x := -u * 0.7 + k * u * 0.35
				draw_colored_polygon(PackedVector2Array([h + Vector2(x - u * 0.12, -u * 0.7), h + Vector2(x, -u * 1.15 - (k % 2) * u * 0.15), h + Vector2(x + u * 0.12, -u * 0.7)]), acc)
	# visor
	var shimmer := 0.85 + 0.15 * sin(t * 3.0)
	var vc := glow * shimmer
	match def.get("visor", "wide"):
		"wide":
			draw_rect(Rect2(h + Vector2(-u * 0.7, -u * 0.25), Vector2(u * 1.4, u * 0.55)), vc)
		"full":
			draw_circle(h + Vector2(0, u * 0.05), u * 0.62, vc)
		"t":
			draw_rect(Rect2(h + Vector2(-u * 0.7, -u * 0.3), Vector2(u * 1.4, u * 0.25)), vc)
			draw_rect(Rect2(h + Vector2(-u * 0.13, -u * 0.3), Vector2(u * 0.26, u * 0.8)), vc)
		"slit":
			draw_rect(Rect2(h + Vector2(-u * 0.6, -u * 0.08), Vector2(u * 1.2, u * 0.14)), vc * 1.3)
			for k in 3:
				draw_rect(Rect2(h + Vector2(-u * 0.2 + k * u * 0.2, u * 0.2), Vector2(u * 0.06, u * 0.3)), base.darkened(0.6))
		"round":
			draw_circle(h + Vector2(-u * 0.28, 0), u * 0.24, vc)
			draw_circle(h + Vector2(u * 0.28, 0), u * 0.24, vc)
		"eye":
			draw_circle(h + Vector2(0, u * 0.05), u * 0.38, Color(0, 0, 0))
			draw_circle(h + Vector2(sin(t * 0.7) * u * 0.08, u * 0.05), u * 0.24, vc)
			draw_circle(h + Vector2(sin(t * 0.7) * u * 0.08, u * 0.05), u * 0.09, Color(1, 1, 1))
	draw_rect(Rect2(h + Vector2(-u * 0.55, -u * 0.22), Vector2(u * 0.35, u * 0.08)), Color(1, 1, 1, 0.45))


func _draw_accessory(c: Vector2, u: float, base: Color, acc: Color, glow: Color) -> void:
	var h := c + Vector2(0, -u * 2.1)
	match def.get("acc", ""):
		"antenna":
			var tip := h + Vector2(u * 0.7 + sin(t * 2.5) * u * 0.12, -u * 1.7)
			draw_line(h + Vector2(u * 0.55, -u * 0.6), tip, base.lightened(0.3), maxf(2.0, u * 0.07), true)
			draw_circle(tip, u * 0.13, glow * (0.7 + 0.5 * absf(sin(t * 3.0))))
		"fins":
			for side in [-1, 1]:
				var sway := sin(t * 2.0 + side) * u * 0.08
				draw_colored_polygon(PackedVector2Array([h + Vector2(side * u * 0.2, -u * 0.8), h + Vector2(side * u * 0.55 + sway, -u * 1.75), h + Vector2(side * u * 0.65, -u * 0.6)]), Color(glow.r, glow.g, glow.b, 0.8))
		"spikes":
			for side in [-1, 1]:
				for k in 3:
					var bx: float = c.x + side * (u * 0.75 + k * u * 0.22)
					draw_colored_polygon(PackedVector2Array([Vector2(bx - u * 0.1, c.y - u * 1.35), Vector2(bx + side * u * 0.12, c.y - u * 1.85 - k * u * 0.12), Vector2(bx + u * 0.1, c.y - u * 1.35)]), glow.lightened(0.3))
		"horns":
			for side in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([h + Vector2(side * u * 0.6, -u * 0.5), h + Vector2(side * u * 1.35, -u * 1.4), h + Vector2(side * u * 0.9, -u * 0.2)]), acc.lightened(0.2))
				draw_circle(h + Vector2(side * u * 1.3, -u * 1.35), u * 0.07, glow)
		"leaves":
			for k in 6:
				var a := t * 0.8 + k * TAU / 6.0
				var p := c + Vector2(cos(a) * u * 1.8, sin(a) * u * 0.6 - u * 0.8)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-u * 0.12, 0), p + Vector2(0, -u * 0.18), p + Vector2(u * 0.12, 0), p + Vector2(0, u * 0.18)]), glow if sin(a) > 0 else acc)
		"halo":
			var hy := h + Vector2(0, -u * 1.25 + sin(t * 1.5) * u * 0.06)
			draw_arc(hy, u * 0.8, 0, TAU, 40, Color(acc.r, acc.g, acc.b, 0.25), u * 0.3, true)
			draw_arc(hy, u * 0.8, 0, TAU, 40, acc, maxf(2.0, u * 0.09), true)
			for k in 3:
				var a2 := t * 1.2 + k * TAU / 3.0
				draw_circle(hy + Vector2(cos(a2) * u * 0.8, sin(a2) * u * 0.25), u * 0.08, glow)

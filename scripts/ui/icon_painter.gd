class_name IconPainter
extends RefCounted
## Vector UI icons drawn with CanvasItem primitives (crisp at any size, no image assets).


static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, w := 0.0) -> void:
	if w <= 0.0:
		w = maxf(2.0, s * 0.12)
	match name:
		"mine":
			# laser drill: body + beam + sparks
			var body := PackedVector2Array([c + Vector2(-0.55, 0.15) * s, c + Vector2(0.05, -0.45) * s, c + Vector2(0.3, -0.2) * s, c + Vector2(-0.3, 0.4) * s])
			ci.draw_colored_polygon(body, col)
			ci.draw_line(c + Vector2(0.15, -0.35) * s, c + Vector2(0.55, -0.75) * s, col.lightened(0.4), w * 0.7, true)
			ci.draw_line(c + Vector2(-0.35, 0.3) * s, c + Vector2(-0.6, 0.6) * s, col, w, true)
			for a in [0.0, 1.3, 2.6]:
				var p := c + Vector2(0.6, -0.8) * s + Vector2(cos(a), sin(a)) * s * 0.18
				ci.draw_circle(p, w * 0.45, col.lightened(0.5))
		"jump":
			for k in 2:
				var y := (0.15 - k * 0.42) * s
				ci.draw_polyline(PackedVector2Array([c + Vector2(-0.5 * s, y + 0.25 * s), c + Vector2(0, y - 0.2 * s), c + Vector2(0.5 * s, y + 0.25 * s)]), col, w, true)
		"use":
			ci.draw_arc(c, s * 0.55, 0, TAU, 32, col, w * 0.7, true)
			ci.draw_circle(c, s * 0.22, col)
			for a in 4:
				var d := Vector2.from_angle(a * PI / 2 + PI / 4)
				ci.draw_line(c + d * s * 0.62, c + d * s * 0.85, col, w * 0.7, true)
		"run":
			for k in 2:
				var x := (-0.3 + k * 0.42) * s
				ci.draw_polyline(PackedVector2Array([c + Vector2(x - 0.15 * s, -0.45 * s), c + Vector2(x + 0.2 * s, 0), c + Vector2(x - 0.15 * s, 0.45 * s)]), col, w, true)
		"bag":
			var r := Rect2(c - Vector2(0.45, 0.3) * s, Vector2(0.9, 0.8) * s)
			ci.draw_rect(r, col, false, w)
			ci.draw_arc(c + Vector2(0, -0.3) * s, s * 0.25, PI, TAU, 12, col, w, true)
			ci.draw_line(c + Vector2(-0.45, 0.05) * s, c + Vector2(0.45, 0.05) * s, col, w * 0.8)
			ci.draw_rect(Rect2(c + Vector2(-0.1, -0.02) * s, Vector2(0.2, 0.16) * s), col)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-0.35, -0.45) * s, Vector2(0.24, 0.9) * s), col)
			ci.draw_rect(Rect2(c + Vector2(0.11, -0.45) * s, Vector2(0.24, 0.9) * s), col)
		"heart":
			ci.draw_circle(c + Vector2(-0.25, -0.15) * s, s * 0.3, col)
			ci.draw_circle(c + Vector2(0.25, -0.15) * s, s * 0.3, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.54, -0.05) * s, c + Vector2(0.54, -0.05) * s, c + Vector2(0, 0.55) * s]), col)
			ci.draw_circle(c + Vector2(-0.3, -0.25) * s, s * 0.09, Color(1, 1, 1, 0.6))
		"o2":
			ci.draw_arc(c, s * 0.5, 0, TAU, 28, col, w * 0.8, true)
			ci.draw_circle(c + Vector2(-0.15, -0.15) * s, s * 0.14, col)
			ci.draw_circle(c + Vector2(0.18, 0.12) * s, s * 0.2, col)
			ci.draw_circle(c + Vector2(-0.22, -0.22) * s, s * 0.05, Color(1, 1, 1, 0.7))
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.1, -0.6) * s, c + Vector2(-0.38, 0.08) * s, c + Vector2(-0.02, 0.08) * s, c + Vector2(-0.12, 0.6) * s, c + Vector2(0.38, -0.12) * s, c + Vector2(0.02, -0.12) * s]), col)
		"food":
			ci.draw_circle(c + Vector2(0.05, 0.08) * s, s * 0.42, col)
			ci.draw_line(c + Vector2(0.05, -0.32) * s, c + Vector2(0.15, -0.55) * s, col.darkened(0.3), w * 0.7)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.15, -0.45) * s, c + Vector2(0.5, -0.6) * s, c + Vector2(0.35, -0.3) * s]), col.lightened(0.2))
			ci.draw_circle(c + Vector2(-0.12, -0.08) * s, s * 0.1, Color(1, 1, 1, 0.55))
		"temp":
			ci.draw_line(c + Vector2(0, -0.55) * s, c + Vector2(0, 0.2) * s, col, w * 1.6, true)
			ci.draw_circle(c + Vector2(0, 0.35) * s, s * 0.25, col)
		"rad":
			ci.draw_circle(c, s * 0.12, col)
			for a in 3:
				var a0 := a * TAU / 3.0 - PI / 2.0
				ci.draw_arc(c, s * 0.38, a0 - 0.45, a0 + 0.45, 8, col, s * 0.32)
		"xp":
			var pts := PackedVector2Array()
			for k in 10:
				var r := s * (0.55 if k % 2 == 0 else 0.24)
				pts.append(c + Vector2.from_angle(-PI / 2 + k * TAU / 10.0) * r)
			ci.draw_colored_polygon(pts, col)
		"quest":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.55) * s, c + Vector2(0.45, 0) * s, c + Vector2(0, 0.55) * s, c + Vector2(-0.45, 0) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.3) * s, c + Vector2(0.22, 0) * s, c + Vector2(0, 0.3) * s, c + Vector2(-0.22, 0) * s]), Color(0, 0, 0, 0.45))
		"talk":
			ci.draw_rect(Rect2(c + Vector2(-0.5, -0.4) * s, Vector2(1.0, 0.65) * s), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, 0.25) * s, c + Vector2(0.1, 0.25) * s, c + Vector2(-0.3, 0.55) * s]), col)
			for k in 3:
				ci.draw_circle(c + Vector2(-0.25 + k * 0.25, -0.08) * s, s * 0.07, Color(0, 0, 0, 0.55))
		_:
			ci.draw_circle(c, s * 0.3, col)

class_name UiAnim
extends RefCounted
## Small tween helpers shared by all menus.


static func pop_in(c: Control, delay := 0.0, from_scale := 0.94) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * from_scale
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_delay(delay)


static func slide_in(c: Control, offset: Vector2, delay := 0.0, dur := 0.35) -> void:
	var target := c.position
	c.position = target + offset
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", target, dur).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.8).set_delay(delay)


static func fade(c: CanvasItem, to: float, dur := 0.15) -> Tween:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", to, dur)
	return tw


static func bounce(c: Control, amount := 0.9) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.scale = Vector2.ONE * amount
	tw.tween_property(c, "scale", Vector2.ONE, 0.22)


static func flash(c: CanvasItem, col := Color(1.6, 1.6, 1.6)) -> void:
	var tw := c.create_tween()
	c.modulate = col
	tw.tween_property(c, "modulate", Color.WHITE, 0.35)

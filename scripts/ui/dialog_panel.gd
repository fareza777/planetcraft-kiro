class_name DialogPanel
extends Control
## NPC conversation: portrait, typewriter greeting, side jobs (accept / turn in) and trading.

signal closed
signal talked(npc_id: String)

const TF := preload("res://scripts/ui/theme_factory.gd")


class Portrait:
	extends Control
	var suit := Color.GRAY
	var visor := Color.CYAN
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var s := size
		draw_style_box(TF.box(Color(0.04, 0.05, 0.12, 1), Color(visor.r, visor.g, visor.b, 0.6), 16, 2, 0), Rect2(Vector2.ZERO, s))
		var c := s * Vector2(0.5, 0.55)
		var r := s.x * 0.32
		draw_rect(Rect2(c + Vector2(-r * 1.3, r * 0.9), Vector2(r * 2.6, r * 1.2)), suit.darkened(0.2))
		draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), suit.lightened(0.1))
		var vy := sin(t * 1.3) * 2.0
		var vis := Rect2(c + Vector2(-r * 0.8, -r * 0.35 + vy), Vector2(r * 1.6, r * 0.6))
		draw_rect(vis, visor * 0.6)
		draw_rect(Rect2(vis.position, Vector2(vis.size.x, vis.size.y * 0.35)), visor * 1.1)
		var scan := fmod(t * 0.6, 1.0)
		draw_rect(Rect2(vis.position + Vector2(vis.size.x * scan - 4, 0), Vector2(8, vis.size.y)), Color(1, 1, 1, 0.35))
		draw_rect(Rect2(c + Vector2(r * 0.55, -r * 1.5), Vector2(r * 0.15, r * 0.6)), suit.darkened(0.4))
		draw_circle(c + Vector2(r * 0.62, -r * 1.55), r * 0.12, visor)


var root: Node
var npc_id := ""
var _portrait: Portrait
var _name: Label
var _role: Label
var _text: Label
var _body: VBoxContainer
var _panel: PanelContainer
var _type_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", TF.box(Color(0.03, 0.03, 0.08, 0.96), TF.LINE, 18, 2, 20))
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	_panel.add_child(h)
	var left := VBoxContainer.new()
	h.add_child(left)
	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(220, 220)
	left.add_child(_portrait)
	_name = TF.label("", 24, TF.TEXT)
	left.add_child(_name)
	_role = TF.label("", 16, TF.AMBER)
	left.add_child(_role)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	left.add_child(TF.button("Goodbye", _close, 220))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	h.add_child(right)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", TF.box(Color(0.07, 0.09, 0.18, 0.95), Color(1, 1, 1, 0.1), 14, 1, 16))
	right.add_child(bubble)
	_text = TF.label("", 20, TF.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	_text.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE | TextServer.JUSTIFICATION_TRIM_EDGE_SPACES
	_text.custom_minimum_size.y = 70
	bubble.add_child(_text)
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	resized.connect(_layout)


func _layout() -> void:
	var m := Vector2(clampf(size.x * 0.06, 20, 120), clampf(size.y * 0.07, 16, 60))
	_panel.position = m
	_panel.size = size - m * 2.0


func open(r: Node, id: String) -> void:
	root = r
	npc_id = id
	var d: Dictionary = Reg.npcs[id]
	_portrait.suit = Color.html(d.suit)
	_portrait.visor = Color.html(d.visor)
	_name.text = d.name
	_role.text = d.role.to_upper()
	var lines: Array = d.get("greet", ["..."])
	_text.text = lines[randi() % lines.size()]
	_text.visible_ratio = 0.0
	_type_t = 0.0
	visible = true
	_layout()
	_build()
	UiAnim.pop_in(_panel, 0.0, 0.94)
	talked.emit(id)


func _process(dt: float) -> void:
	if visible and _text.visible_ratio < 1.0:
		_type_t += dt
		_text.visible_ratio = minf(1.0, _type_t * 40.0 / maxf(_text.text.length(), 1))


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	var d: Dictionary = Reg.npcs[npc_id]
	var q: Quests = root.quests
	var jobs: Array = d.get("jobs", [])
	if not jobs.is_empty():
		_body.add_child(TF.label("JOBS", 18, TF.AMBER))
	for sid in jobs:
		var sq: Dictionary = Reg.side_quests.get(sid, {})
		if sq.is_empty():
			continue
		var state := q.side_state(sid)
		if state == "done":
			continue
		_body.add_child(_job_card(sq, state))
	if d.get("trade", false):
		_body.add_child(TF.label("TRADE  ·  you have %d credit chips" % root.player.inv.count(Reg.trades.get("currency", "credits_chip")), 18, TF.CYAN))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		_body.add_child(grid)
		for o in Reg.trades.get("sell", []):
			grid.add_child(_trade_row(o, true))
		for o in Reg.trades.get("buy", []):
			grid.add_child(_trade_row(o, false))


func _job_card(sq: Dictionary, state: String) -> Control:
	var q: Quests = root.quests
	var col := TF.GREEN if state == "ready" else (TF.AMBER if state == "active" else TF.LINE)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", TF.box(Color(0.06, 0.07, 0.15, 0.95), col, 12, 2, 14))
	var h := HBoxContainer.new()
	pc.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(TF.label(sq.title + ("  ·  repeatable" if sq.get("repeat", false) else ""), 19, TF.TEXT))
	var t := TF.label(sq.text, 16, TF.DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var rw := HBoxContainer.new()
	v.add_child(rw)
	rw.add_child(TF.label("Reward:", 15, TF.GREEN))
	for r in sq.get("reward", []):
		var ic := TextureRect.new()
		ic.texture = Reg.icon(r[0])
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rw.add_child(ic)
		rw.add_child(TF.label("%s ×%d" % [Reg.item_label(r[0]), int(r[1])], 15))
	if state != "available":
		var gp := q.goal_progress(sq, int(q.side.get(sq.id, {}).get("progress", 0)))
		var bar := ProgressBar.new()
		bar.max_value = gp.y
		bar.value = gp.x
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 16)
		bar.add_theme_stylebox_override("fill", TF.bar_fill(col))
		v.add_child(bar)
	var b: Button
	match state:
		"available":
			b = TF.button("Accept", _accept.bind(sq.id), 150)
		"active":
			b = TF.button("In progress", func() -> void: pass, 150)
			b.disabled = true
		"ready":
			b = TF.button("Turn in", _turn_in.bind(sq.id), 150)
			b.add_theme_stylebox_override("normal", TF.box(Color(0.12, 0.38, 0.32, 0.95), TF.GREEN, 10, 2, 12))
	h.add_child(b)
	return pc


func _trade_row(o: Dictionary, selling: bool) -> Control:
	var cur: String = Reg.trades.get("currency", "credits_chip")
	var inv: Inventory = root.player.inv
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", TF.box(Color(0.06, 0.07, 0.14, 0.9), Color(1, 1, 1, 0.08), 10, 1, 8))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	pc.add_child(h)
	var ic := TextureRect.new()
	ic.texture = Reg.icon(o.item)
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(ic)
	var l := TF.label("%s ×%d" % [Reg.item_label(o.item), int(o.n)], 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var price := int(o.price)
	var b := TF.button(("Buy %d ¢" if selling else "Sell +%d ¢") % price, _trade.bind(o, selling), 140)
	b.custom_minimum_size.y = 44
	b.disabled = (inv.count(cur) < price) if selling else (inv.count(o.item) < int(o.n))
	h.add_child(b)
	return pc


func _trade(o: Dictionary, selling: bool) -> void:
	var cur: String = Reg.trades.get("currency", "credits_chip")
	var inv: Inventory = root.player.inv
	if selling:
		if inv.remove(cur, int(o.price)):
			inv.add(o.item, int(o.n))
	else:
		if inv.remove(o.item, int(o.n)):
			inv.add(cur, int(o.price))
	root.sfx.play("pickup", -2.0)
	_build()


func _accept(sid: String) -> void:
	root.quests.accept(sid)
	root.sfx.play("quest", -4.0)
	root.hud.toast("Job accepted: " + Reg.side_quests[sid].title, TF.AMBER)
	root.quests.check_collect()
	_build()


func _turn_in(sid: String) -> void:
	if root.quests.turn_in(sid):
		_text.text = "Perfect. Exactly what I needed. Here, you've earned this."
		_text.visible_ratio = 0.0
		_type_t = 0.0
	_build()


func _close() -> void:
	visible = false
	closed.emit()

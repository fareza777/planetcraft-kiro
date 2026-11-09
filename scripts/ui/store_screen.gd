class_name StoreScreen
extends VBoxContainer
## Stellar Store (title screen). Cosmetics and starter kits bought with Stellar Shards, an
## account-wide currency that only drops rarely (elites, bosses, relics, trials).

const TF := preload("res://scripts/ui/theme_factory.gd")
const CATS := [["suit", "SUITS"], ["laser", "LASERS"], ["rover", "ROVERS"], ["ship", "SHIPS"], ["kit", "STARTER KITS"]]

var _cat := "suit"
var _grid: GridContainer
var _balance: Label
var _tabs := {}


class Preview:
	extends Control
	var cat := ""
	var cols: Array = []
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		draw_style_box(TF.box(Color(0.02, 0.02, 0.06, 1), Color(1, 1, 1, 0.06), 10, 1, 0), Rect2(Vector2.ZERO, s))
		var a: Color = cols[0]
		var b: Color = cols[1] if cols.size() > 1 else a
		var g: Color = cols[2] if cols.size() > 2 else b
		match cat:
			"suit":
				var r := s.y * 0.26
				draw_rect(Rect2(c + Vector2(-r * 1.2, r * 0.7), Vector2(r * 2.4, r * 1.4)), a)
				draw_rect(Rect2(c + Vector2(-r * 1.2, r * 0.7), Vector2(r * 2.4, r * 0.18)), b)
				draw_rect(Rect2(c - Vector2(r, r * 1.1), Vector2(r * 2, r * 1.8)), a.lightened(0.1))
				draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.55), Vector2(r * 1.5, r * 0.5)), g * (0.9 + 0.2 * sin(t * 3.0)))
				draw_rect(Rect2(c + Vector2(-r, -r * 1.1), Vector2(r * 2, r * 0.15)), b)
			"laser":
				var x0 := s.x * 0.12
				draw_rect(Rect2(Vector2(x0, c.y - 10), Vector2(s.x * 0.25, 20)), Color(0.25, 0.27, 0.34))
				var flick := 0.8 + 0.2 * sin(t * 30.0)
				draw_line(Vector2(x0 + s.x * 0.25, c.y), Vector2(s.x * 0.9, c.y + sin(t * 4.0) * 4.0), a * flick, 7.0, true)
				draw_line(Vector2(x0 + s.x * 0.25, c.y), Vector2(s.x * 0.9, c.y + sin(t * 4.0) * 4.0), Color(1, 1, 1, 0.8), 2.0, true)
				for k in 5:
					var p := Vector2(s.x * 0.9, c.y) + Vector2.from_angle(t * 5.0 + k * 1.3) * (6.0 + k * 2.0)
					draw_circle(p, 2.5, a.lightened(0.4))
			"rover":
				var w := s.x * 0.62
				var y := c.y + sin(t * 8.0) * 1.5
				draw_rect(Rect2(c.x - w * 0.5, y - 14, w, 22), a)
				draw_rect(Rect2(c.x - w * 0.5, y - 18, w, 5), b)
				draw_rect(Rect2(c.x - w * 0.25, y - 34, w * 0.4, 18), a.darkened(0.2))
				draw_rect(Rect2(c.x - w * 0.22, y - 31, w * 0.32, 8), g)
				for k in 3:
					draw_circle(Vector2(c.x - w * 0.36 + k * w * 0.36, y + 12), 11, Color(0.08, 0.08, 0.1))
					draw_circle(Vector2(c.x - w * 0.36 + k * w * 0.36, y + 12), 4, Color(0.4, 0.42, 0.5))
			"ship":
				var y2 := c.y + sin(t * 2.0) * 4.0
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - s.x * 0.36, y2 + 10), Vector2(c.x + s.x * 0.3, y2 - 6), Vector2(c.x + s.x * 0.38, y2 + 4), Vector2(c.x - s.x * 0.3, y2 + 22)]), a)
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - s.x * 0.1, y2 + 8), Vector2(c.x + s.x * 0.05, y2 - 30), Vector2(c.x + s.x * 0.14, y2 + 2)]), b)
				draw_rect(Rect2(c.x + s.x * 0.16, y2 - 6, s.x * 0.1, 8), g)
				draw_circle(Vector2(c.x - s.x * 0.36, y2 + 16), 6.0 + sin(t * 20.0) * 2.0, Color(1.0, 0.7, 0.3))
			"kit":
				draw_rect(Rect2(c - Vector2(s.y * 0.3, s.y * 0.22), Vector2(s.y * 0.6, s.y * 0.44)), a.darkened(0.2))
				draw_rect(Rect2(c - Vector2(s.y * 0.3, s.y * 0.22), Vector2(s.y * 0.6, s.y * 0.1)), b)
				draw_line(c - Vector2(s.y * 0.3, s.y * 0.22), c + Vector2(s.y * 0.3, s.y * 0.22), b, 3.0)
				draw_line(c + Vector2(-s.y * 0.3, s.y * 0.22), c + Vector2(s.y * 0.3, -s.y * 0.22), b, 3.0)


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	add_child(head)
	var ic := TextureRect.new()
	ic.texture = Reg.icon("stellar_shard")
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(ic)
	_balance = TF.label("", 26, TF.AMBER)
	_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_balance)
	var how := TF.label("Shards drop rarely: elite (★) monsters, bosses, precursor relics, obelisk trials and starfalls. Purchases are offline, permanent and shared by every expedition.", 15, TF.DIM)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(how)
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for c in CATS:
		var b := Button.new()
		b.text = c[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_stylebox_override("pressed", TF.box(Color(0.3, 0.2, 0.05, 0.95), TF.AMBER, 10, 2, 14))
		b.pressed.connect(_set_cat.bind(c[0]))
		tabs.add_child(b)
		_tabs[c[0]] = b
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	add_child(_grid)
	_refresh()


func _set_cat(c: String) -> void:
	_cat = c
	_refresh()


func _refresh() -> void:
	_balance.text = "%d Stellar Shards" % int(Game.profile.shards)
	for k in _tabs:
		_tabs[k].set_pressed_no_signal(k == _cat)
	for c in _grid.get_children():
		c.queue_free()
	var i := 0
	for id in Reg.store_order:
		var it: Dictionary = Reg.store[id]
		if it.cat != _cat:
			continue
		var card := _card(it)
		_grid.add_child(card)
		UiAnim.pop_in(card, i * 0.04, 0.9)
		i += 1


func _card(it: Dictionary) -> Control:
	var owned: bool = Game.owns(it.id)
	var eq: bool = Game.equipped(it.cat) == it.id
	var legendary: bool = int(it.price) >= 100
	var border := TF.AMBER if legendary else (TF.GREEN if eq else TF.LINE)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(300, 0)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", TF.box(Color(0.05, 0.05, 0.12, 0.95), border, 14, 2, 12))
	var v := VBoxContainer.new()
	pc.add_child(v)
	var pv := Preview.new()
	pv.cat = it.cat
	for c in it.colors:
		pv.cols.append(Color.html(c))
	pv.custom_minimum_size = Vector2(260, 110)
	v.add_child(pv)
	v.add_child(TF.label(it.name, 20, TF.AMBER if legendary else TF.TEXT))
	var d := TF.label(it.desc, 14, TF.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.y = 40
	v.add_child(d)
	var b: Button
	if it.cat == "kit":
		b = TF.button("OWNED · applies to new expeditions" if owned else "Buy · %d ✦" % int(it.price), _buy.bind(it.id), 200)
		b.disabled = owned or int(Game.profile.shards) < int(it.price)
	elif eq:
		b = TF.button("EQUIPPED", func() -> void: pass, 200)
		b.disabled = true
	elif owned:
		b = TF.button("Equip", _equip.bind(it.id), 200)
	else:
		b = TF.button(("Buy · %d ✦" % int(it.price)) if int(it.price) > 0 else "Free", _buy.bind(it.id), 200)
		b.disabled = int(Game.profile.shards) < int(it.price)
	v.add_child(b)
	return pc


func _buy(id: String) -> void:
	if Game.buy(id):
		_refresh()


func _equip(id: String) -> void:
	Game.equip(id)
	_refresh()

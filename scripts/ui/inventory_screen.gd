class_name InventoryScreen
extends Control
## Inventory grid + fabrication list. Tap a slot, then another slot to move/swap.

signal closed

const TF := preload("res://scripts/ui/theme_factory.gd")

var player: Player
var stations: Array = []
var _sel := -1
var _grid: GridContainer
var _recipes: VBoxContainer
var _info: Label
var _station_lbl: Label
var _use_btn: Button
var _slot_btns: Array = []
var _filter := "all"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 30
	panel.offset_bottom = -30
	add_child(panel)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	panel.add_child(root)
	# left: inventory
	var left := VBoxContainer.new()
	root.add_child(left)
	left.add_child(TF.label("INVENTORY", 26, TF.CYAN))
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	for i in Inventory.SIZE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(68, 68)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_slot.bind(i))
		_grid.add_child(b)
		_slot_btns.append(b)
	_info = TF.label("", 18, TF.DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(600, 60)
	left.add_child(_info)
	var row := HBoxContainer.new()
	left.add_child(row)
	_use_btn = TF.button("Use / Install", _on_use, 200)
	row.add_child(_use_btn)
	row.add_child(TF.button("Close", _on_close, 160))
	# right: crafting
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	right.add_child(TF.label("FABRICATION", 26, TF.AMBER))
	_station_lbl = TF.label("", 16, TF.DIM)
	_station_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_station_lbl)
	var tabs := HBoxContainer.new()
	right.add_child(tabs)
	for f in [["all", "All"], ["ready", "Can craft"]]:
		var tb := TF.button(f[1], _set_filter.bind(f[0]), 130)
		tb.custom_minimum_size.y = 44
		tabs.add_child(tb)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_recipes = VBoxContainer.new()
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipes)


func open(p: Player, st: Array) -> void:
	player = p
	stations = st
	_sel = -1
	if not player.inv.changed.is_connected(_refresh):
		player.inv.changed.connect(_refresh)
	var names := []
	for s in stations:
		names.append(s.capitalize())
	_station_lbl.text = "Nearby stations: " + (", ".join(names) if not names.is_empty() else "none (hand crafting only)") + ".  Place stations within 5 blocks to unlock more recipes."
	visible = true
	_refresh()


func _set_filter(f: String) -> void:
	_filter = f
	_refresh()


func _refresh() -> void:
	if player == null or not visible:
		return
	for i in Inventory.SIZE:
		var b: Button = _slot_btns[i]
		var s = player.inv.slots[i]
		b.icon = Reg.icon(s.id) if s != null else null
		b.text = str(s.n) if s != null and s.n > 1 else ""
		var col := Color(0.15, 0.3, 0.42, 0.95) if i == _sel else (Color(0.1, 0.1, 0.2, 0.95) if i < 9 else Color(0.06, 0.07, 0.14, 0.92))
		var border := TF.AMBER if i == _sel else (TF.LINE if i < 9 else Color(1, 1, 1, 0.1))
		b.add_theme_stylebox_override("normal", TF.box(col, border, 8, 2, 4))
		b.add_theme_stylebox_override("hover", TF.box(col.lightened(0.1), TF.CYAN, 8, 2, 4))
		b.add_theme_stylebox_override("pressed", TF.box(col.lightened(0.2), TF.CYAN, 8, 2, 4))
	var s = player.inv.slots[_sel] if _sel >= 0 else null
	if s != null:
		var it := Reg.item(s.id)
		_info.text = "%s ×%d — %s" % [it.label, s.n, _describe(it)]
	else:
		_info.text = "Tap a slot to select it, then tap another slot to move or swap. Slots in the first row are your hotbar."
	_use_btn.disabled = s == null or not ["food", "consumable", "upgrade"].has(Reg.item(s.id).get("type", ""))
	_build_recipes()


func _describe(it: Dictionary) -> String:
	match it.get("type", ""):
		"block": return "Placeable block."
		"food": return "Food: +%d nutrition." % int(it.get("food", 0))
		"consumable": return "Consumable."
		"tool": return "Mining tool, tier %d, speed ×%.1f. Works from anywhere in your inventory." % [int(it.tool.tier), float(it.tool.speed)]
		"weapon": return "Weapon: %d damage." % int(it.weapon.dmg)
		"upgrade": return "Suit upgrade. Tap Use / Install."
		"ship_part": return "Spaceship component."
		_: return "Crafting material."


func _build_recipes() -> void:
	for c in _recipes.get_children():
		c.queue_free()
	var rows := []
	for r in Reg.recipes:
		var st: String = r.get("station", "hand")
		var station_ok := st == "hand" or stations.has(st)
		var can := station_ok and player.inv.can_craft(r)
		if _filter == "ready" and not can:
			continue
		rows.append([0 if can else (1 if station_ok else 2), r, station_ok, can])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for e in rows:
		_recipes.add_child(_recipe_row(e[1], e[2], e[3]))


func _recipe_row(r: Dictionary, station_ok: bool, can: bool) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", TF.box(Color(0.07, 0.08, 0.16, 0.9) if station_ok else Color(0.05, 0.05, 0.09, 0.7), TF.LINE if can else Color(1, 1, 1, 0.08), 10, 1, 8))
	var h := HBoxContainer.new()
	pc.add_child(h)
	var icon := TextureRect.new()
	icon.texture = Reg.icon(r.out)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var n := int(r.get("n", 1))
	v.add_child(TF.label(Reg.item_label(r.out) + (" ×%d" % n if n > 1 else ""), 19, TF.TEXT if station_ok else TF.DIM))
	var ing := HBoxContainer.new()
	ing.add_theme_constant_override("separation", 4)
	v.add_child(ing)
	for k in r.in:
		var need := int(r.in[k])
		var have := player.inv.count(k)
		var ti := TextureRect.new()
		ti.texture = Reg.icon(k)
		ti.custom_minimum_size = Vector2(26, 26)
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ti.tooltip_text = Reg.item_label(k)
		ing.add_child(ti)
		ing.add_child(TF.label("%d/%d" % [mini(have, need), need], 15, TF.GREEN if have >= need else TF.RED))
	var st: String = r.get("station", "hand")
	if not station_ok:
		v.add_child(TF.label("Requires: " + Reg.item_label(st), 14, TF.AMBER))
	var b := TF.button("Craft", _on_craft.bind(r), 110)
	b.disabled = not can
	h.add_child(b)
	return pc


func _on_craft(r: Dictionary) -> void:
	if player.inv.craft(r):
		Game.notify_crafted(r.out, int(r.get("n", 1)))


func _on_slot(i: int) -> void:
	if _sel < 0:
		if player.inv.slots[i] != null:
			_sel = i
	elif _sel == i:
		_sel = -1
	else:
		player.inv.swap(_sel, i)
		_sel = -1
	_refresh()


func _on_use() -> void:
	if _sel < 0:
		return
	var s = player.inv.slots[_sel]
	if s == null:
		return
	var it := Reg.item(s.id)
	if it.get("type", "") == "upgrade":
		var u: Dictionary = player.stats.upgrades.duplicate()
		if u.has(it.upgrade):
			return
		u[it.upgrade] = true
		player.stats.apply_upgrades(u)
		player.inv.remove_at(_sel, 1)
	elif player.stats.consume(it):
		player.inv.remove_at(_sel, 1)
	if player.inv.slots[_sel] == null:
		_sel = -1
	_refresh()


func _on_close() -> void:
	visible = false
	closed.emit()

class_name InventoryScreen
extends Control
## Item screen with four tabs: Inventory, Fabricate, Suit, Directives.
## Responsive: slot size follows the screen. Fast: recipe rows are built once and only their
## state is refreshed; nothing is rebuilt on a tap.

signal closed

const TF := preload("res://scripts/ui/theme_factory.gd")
const CATS := [["all", "All"], ["ready", "Ready"], ["machines", "Machines"], ["gear", "Gear"], ["materials", "Materials"], ["supplies", "Supplies"], ["blocks", "Blocks"], ["ship", "Ship"]]

var player: Player
var quests: Quests
var evolution: Evolution
var stations: Array = []
var _sel := -1
var _tab := 0
var _cat := "all"
var _sel_recipe := -1

var _panel: PanelContainer
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _slots: Array[SlotView] = []
var _grid: GridContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_type: Label
var _detail_desc: Label
var _btn_use: Button
var _btn_hotbar: Button
var _btn_drop: Button
var _station_lbl: Label
var _cat_btns: Dictionary = {}
var _rows: Array = []      # {recipe, box, icon, name, ing:[[TextureRect, Label, id, need]], state}
var _list: VBoxContainer
var _rd_icon: TextureRect
var _rd_name: Label
var _rd_desc: Label
var _rd_ing: VBoxContainer
var _rd_craft: Button
var _rd_craft5: Button
var _rd_station: Label
var _suit_box: VBoxContainer
var _quest_box: VBoxContainer
var _dirty := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", TF.box(Color(0.03, 0.03, 0.08, 0.95), TF.LINE, 18, 2, 18))
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)
	# tab bar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	outer.add_child(bar)
	for i in 4:
		var names := ["INVENTORY", "FABRICATE", "SUIT", "JOURNAL"]
		var b := _tab_button(names[i])
		b.pressed.connect(_set_tab.bind(i))
		bar.add_child(b)
		_tabs.append(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var close := TF.button("✕", _on_close, 64)
	close.custom_minimum_size = Vector2(64, 52)
	bar.add_child(close)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(stack)
	_pages = [_build_inventory(), _build_fabricate(), _build_suit(), _build_quests()]
	for p in _pages:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(p)
	resized.connect(_layout)


func _tab_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 52)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_stylebox_override("normal", TF.box(Color(0.07, 0.08, 0.16, 0.9), Color(1, 1, 1, 0.08), 12, 2, 14))
	b.add_theme_stylebox_override("hover", TF.box(Color(0.1, 0.13, 0.24, 0.95), TF.LINE, 12, 2, 14))
	b.add_theme_stylebox_override("pressed", TF.box(Color(0.12, 0.3, 0.42, 0.98), TF.CYAN, 12, 2, 14))
	b.add_theme_stylebox_override("hover_pressed", TF.box(Color(0.14, 0.34, 0.46, 0.98), TF.CYAN, 12, 2, 14))
	return b


func _card() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", TF.box(Color(0.06, 0.07, 0.14, 0.92), Color(1, 1, 1, 0.08), 14, 1, 14))
	return pc


# ---------------------------------------------------------------- inventory tab

func _build_inventory() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	h.add_child(left)
	left.add_child(TF.label("HOTBAR  ·  first row", 15, TF.DIM))
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	for i in Inventory.SIZE:
		var s := SlotView.new()
		s.index = i
		s.hotbar = i < 9
		s.tapped.connect(_on_slot)
		_grid.add_child(s)
		_slots.append(s)
	left.add_child(TF.label("Tap an item to inspect it. Tap a second slot to move or swap.", 15, TF.DIM))
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(112, 112)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_detail_icon)
	_detail_name = TF.label("", 24, TF.TEXT)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_detail_name)
	_detail_type = TF.label("", 16, TF.AMBER)
	_detail_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_detail_type)
	_detail_desc = TF.label("", 17, TF.DIM)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_detail_desc)
	_btn_use = TF.button("Use / Install", _on_use, 200)
	_btn_hotbar = TF.button("Move to hotbar", _on_to_hotbar, 200)
	_btn_drop = TF.button("Discard", _on_drop, 200)
	for b in [_btn_use, _btn_hotbar, _btn_drop]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(b)
	_btn_drop.add_theme_color_override("font_color", TF.RED)
	return h


func _layout() -> void:
	if _panel == null:
		return
	var m := Vector2(clampf(size.x * 0.03, 16, 60), clampf(size.y * 0.04, 12, 40))
	_panel.position = m
	_panel.size = size - m * 2.0
	var avail_w := _panel.size.x * 0.6 - 40
	var avail_h := _panel.size.y - 52 - 12 - 100
	var s := clampf(minf((avail_w - 8 * 6) / 9.0, (avail_h - 3 * 6) / 4.0), 46, 92)
	for sv in _slots:
		sv.custom_minimum_size = Vector2(s, s)


func _describe(it: Dictionary) -> Array:
	var t: String = it.get("type", "material")
	match t:
		"block":
			var d := Reg.block_def(int(it.block))
			var parts := []
			if d.has("machine") or d.has("station"):
				var pw := float(d.get("power", 0))
				if pw > 0:
					parts.append("Generates %d kW." % int(pw))
				elif pw < 0:
					parts.append("Uses %d kW." % int(-pw))
				if d.has("range"):
					parts.append("Range %d blocks." % int(d.range))
				if d.has("station"):
					parts.append("Crafting station: unlocks %s recipes nearby." % Reg.item_label(d.station))
				parts.append("Place it, then aim and tap USE to open it.")
				return ["MACHINE", " ".join(parts)]
			var hard := float(d.get("hard", 1))
			return ["BLOCK", "Building block. Hardness %.1f%s." % [hard, (", needs tier %d tool" % int(d.tier)) if int(d.get("tier", 0)) > 0 else ""]]
		"tool":
			return ["TOOL · TIER %d" % int(it.tool.tier), "Mining speed ×%.1f, %d damage to creatures. Works from any slot; the best tool you carry is used automatically." % [float(it.tool.speed), int(it.tool.dmg)]]
		"weapon":
			var w: Dictionary = it.weapon
			if w.get("melee", false):
				return ["MELEE WEAPON", "%d damage per swing, %.1f s cooldown. Select it and hold MINE." % [int(w.dmg), float(w.rate)]]
			return ["RANGED WEAPON", "%d damage, %.1f shots/s, %.1f energy per shot%s. Select it and hold MINE." % [int(w.dmg), 1.0 / float(w.rate), float(w.energy), ", explosive" if w.has("splash") else ""]]
		"food":
			return ["FOOD", "+%d nutrition%s." % [int(it.get("food", 0)), (", %+d health" % int(it.hp)) if it.has("hp") else ""]]
		"consumable":
			var fx := []
			for k in [["hp", "health"], ["o2", "oxygen"], ["energy", "energy"], ["rad", "radiation"]]:
				if it.has(k[0]):
					fx.append("%+d %s" % [int(it[k[0]]), k[1]])
			if it.get("lure", false):
				return ["CONSUMABLE", "Aim at a tameable creature and tap USE to tame it."]
			return ["CONSUMABLE", ", ".join(fx) + "."]
		"upgrade":
			var u := {"o2": "Doubles oxygen capacity.", "thermal": "Survive -80 to +110 °C.", "rad": "Blocks 85% of radiation.", "jet": "Stronger, cheaper jetpack.", "armor": "+50% health, -30% damage taken."}
			return ["SUIT UPGRADE", u.get(it.upgrade, "") + " Tap Use / Install."]
		"ship_part":
			return ["STARSHIP PART", "Install at a Launch Pad (aim at it, tap USE)."]
		"deploy":
			return ["VEHICLE", "Select it, aim at the ground and tap USE to deploy."]
		"research":
			return ["RESEARCH", "Precursor data. Used in advanced recipes."]
	return ["MATERIAL", "Crafting material."]


func _update_detail() -> void:
	var s = player.inv.slots[_sel] if _sel >= 0 else null
	var has := s != null
	_btn_use.visible = has
	_btn_hotbar.visible = has and _sel >= 9
	_btn_drop.visible = has
	if not has:
		_detail_icon.texture = null
		_detail_name.text = "No item selected"
		_detail_type.text = ""
		_detail_desc.text = "Tip: tools in any slot are used automatically. Keep blocks, food and weapons on the hotbar."
		return
	var it := Reg.item(s.id)
	_detail_icon.texture = Reg.icon(s.id)
	_detail_name.text = "%s  ×%d" % [it.label, s.n] if s.n > 1 else it.label
	var d := _describe(it)
	_detail_type.text = d[0]
	_detail_type.add_theme_color_override("font_color", SlotView.category_color(s.id))
	_detail_desc.text = d[1]
	var usable: bool = it.get("type", "") in ["food", "consumable", "upgrade"]
	_btn_use.disabled = not usable or (it.get("type", "") == "upgrade" and player.stats.upgrades.has(it.get("upgrade", "")))
	_btn_use.text = "Install" if it.get("type", "") == "upgrade" else ("Eat" if it.get("type", "") == "food" else "Use")


func _refresh_slots() -> void:
	for i in Inventory.SIZE:
		var s = player.inv.slots[i]
		_slots[i].set_item(s.id if s != null else "", int(s.n) if s != null else 0)
		_slots[i].set_selected(i == _sel)


func _on_slot(i: int) -> void:
	if player.sfx != null:
		player.sfx.play("ui", -6.0)
	if _sel >= 0 and _sel != i and player.inv.slots[_sel] != null:
		player.inv.swap(_sel, i)
		UiAnim.bounce(_slots[i], 0.82)
		_sel = i if player.inv.slots[i] != null else -1
	elif _sel == i:
		_sel = -1
	else:
		_sel = i if player.inv.slots[i] != null else -1
		if _sel >= 0:
			UiAnim.bounce(_slots[i], 0.88)
			UiAnim.pop_in(_detail_icon, 0.0, 0.7)
	_refresh_slots()
	_update_detail()


func _on_use() -> void:
	if _sel < 0 or player.inv.slots[_sel] == null:
		return
	var it := Reg.item(player.inv.slots[_sel].id)
	if it.get("type", "") == "upgrade":
		var u: Dictionary = player.stats.upgrades.duplicate()
		if u.has(it.upgrade):
			return
		u[it.upgrade] = true
		player.stats.apply_upgrades(u)
		player.inv.remove_at(_sel, 1)
		player.toast.emit("Installed " + it.label, TF.GREEN)
	elif player.stats.consume(it):
		player.inv.remove_at(_sel, 1)
	if player.sfx != null:
		player.sfx.play("pickup", -4.0)
	UiAnim.flash(_detail_icon)
	if player.inv.slots[_sel] == null:
		_sel = -1


func _on_to_hotbar() -> void:
	for i in 9:
		if player.inv.slots[i] == null:
			player.inv.swap(_sel, i)
			_sel = i
			UiAnim.bounce(_slots[i], 0.8)
			return
	player.inv.swap(_sel, player.selected)
	_sel = player.selected


func _on_drop() -> void:
	if _sel >= 0:
		player.inv.slots[_sel] = null
		player.inv.changed.emit()
		_sel = -1


# ---------------------------------------------------------------- fabricate tab

func _category(r: Dictionary) -> String:
	var it := Reg.item(r.out)
	match it.get("type", ""):
		"block":
			var d := Reg.block_def(int(it.block))
			return "machines" if (d.has("machine") or d.has("station")) else "blocks"
		"tool", "weapon", "upgrade": return "gear"
		"ship_part", "deploy": return "ship"
		"food", "consumable": return "supplies"
	return "materials"


func _build_fabricate() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	v.add_child(chips)
	for c in CATS:
		var b := _tab_button(c[1])
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_set_cat.bind(c[0]))
		chips.add_child(b)
		_cat_btns[c[0]] = b
	_station_lbl = TF.label("", 15, TF.DIM)
	v.add_child(_station_lbl)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.4
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	for i in Reg.recipes.size():
		_rows.append(_make_row(i, Reg.recipes[i]))
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(card)
	var d := VBoxContainer.new()
	d.add_theme_constant_override("separation", 10)
	card.add_child(d)
	_rd_icon = TextureRect.new()
	_rd_icon.custom_minimum_size = Vector2(96, 96)
	_rd_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rd_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rd_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rd_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	d.add_child(_rd_icon)
	_rd_name = TF.label("Select a recipe", 22)
	_rd_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rd_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_child(_rd_name)
	_rd_station = TF.label("", 15, TF.AMBER)
	_rd_station.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_child(_rd_station)
	_rd_desc = TF.label("", 15, TF.DIM)
	_rd_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_child(_rd_desc)
	_rd_ing = VBoxContainer.new()
	_rd_ing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.add_child(_rd_ing)
	var cr := HBoxContainer.new()
	d.add_child(cr)
	_rd_craft = TF.button("CRAFT", _craft.bind(1), 150)
	_rd_craft5 = TF.button("×5", _craft.bind(5), 80)
	_rd_craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rd_craft.add_theme_stylebox_override("normal", TF.box(Color(0.15, 0.4, 0.3, 0.95), TF.GREEN, 12, 2, 14))
	_rd_craft.add_theme_stylebox_override("hover", TF.box(Color(0.2, 0.5, 0.38, 0.95), TF.GREEN, 12, 2, 14))
	cr.add_child(_rd_craft)
	cr.add_child(_rd_craft5)
	return v


func _make_row(i: int, r: Dictionary) -> Dictionary:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 58)
	b.toggle_mode = true
	b.pressed.connect(_select_recipe.bind(i))
	_list.add_child(b)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	b.add_child(h)
	var ic := TextureRect.new()
	ic.texture = Reg.icon(r.out)
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var n := int(r.get("n", 1))
	var nm := TF.label(Reg.item_label(r.out) + (" ×%d" % n if n > 1 else ""), 18)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nm)
	var st := TF.label("", 14, TF.DIM)
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(st)
	return {"r": r, "btn": b, "name": nm, "state": st, "cat": _category(r), "can": false, "ok": false}


func _station_ok(r: Dictionary) -> bool:
	var st: String = r.get("station", "hand")
	return st == "hand" or stations.has(st)


func _refresh_recipes() -> void:
	var order := []
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var r: Dictionary = row.r
		row.ok = _station_ok(r)
		row.can = row.ok and player.inv.can_craft(r)
		var show: bool = _cat == "all" or (_cat == "ready" and row.can) or row.cat == _cat
		row.btn.visible = show
		row.name.add_theme_color_override("font_color", TF.TEXT if row.ok else TF.DIM)
		row.state.text = "READY" if row.can else ("" if row.ok else "needs " + Reg.item_label(r.get("station", "hand")))
		row.state.add_theme_color_override("font_color", TF.GREEN if row.can else TF.AMBER)
		var border := TF.GREEN if row.can else (TF.LINE if row.ok else Color(1, 1, 1, 0.06))
		var bg := Color(0.07, 0.09, 0.17, 0.92) if row.ok else Color(0.04, 0.04, 0.08, 0.8)
		row.btn.add_theme_stylebox_override("normal", TF.box(bg, border, 10, 1, 6))
		row.btn.add_theme_stylebox_override("hover", TF.box(bg.lightened(0.06), TF.CYAN, 10, 1, 6))
		row.btn.add_theme_stylebox_override("pressed", TF.box(Color(0.12, 0.3, 0.42, 0.98), TF.AMBER, 10, 2, 6))
		row.btn.set_pressed_no_signal(i == _sel_recipe)
		order.append([0 if row.can else (1 if row.ok else 2), i])
	order.sort()
	for k in order.size():
		_list.move_child(_rows[order[k][1]].btn, k)
	for c in _cat_btns:
		_cat_btns[c].set_pressed_no_signal(c == _cat)
	_update_recipe_detail()


func _set_cat(c: String) -> void:
	_cat = c
	_refresh_recipes()


func _select_recipe(i: int) -> void:
	_sel_recipe = i
	if player.sfx != null:
		player.sfx.play("ui", -8.0)
	for k in _rows.size():
		_rows[k].btn.set_pressed_no_signal(k == i)
	UiAnim.pop_in(_rd_icon, 0.0, 0.7)
	_update_recipe_detail()


func _update_recipe_detail() -> void:
	for c in _rd_ing.get_children():
		c.queue_free()
	if _sel_recipe < 0:
		_rd_icon.texture = null
		_rd_name.text = "Select a recipe"
		_rd_station.text = ""
		_rd_desc.text = "Recipes that need a station (Fabricator, Smelter, Assembler, Refinery) unlock when you stand within 5 blocks of it."
		_rd_craft.disabled = true
		_rd_craft5.disabled = true
		return
	var r: Dictionary = Reg.recipes[_sel_recipe]
	var it := Reg.item(r.out)
	_rd_icon.texture = Reg.icon(r.out)
	var n := int(r.get("n", 1))
	_rd_name.text = it.label + (" ×%d" % n if n > 1 else "")
	var st: String = r.get("station", "hand")
	_rd_station.text = "Hand crafted" if st == "hand" else ("Station: " + Reg.item_label(st) + ("  ✔" if stations.has(st) else "  ✕ not nearby"))
	_rd_desc.text = _describe(it)[1]
	for k in r.in:
		var need := int(r.in[k])
		var have := player.inv.count(k)
		var row := HBoxContainer.new()
		var ic := TextureRect.new()
		ic.texture = Reg.icon(k)
		ic.custom_minimum_size = Vector2(36, 36)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(ic)
		var l := TF.label(Reg.item_label(k), 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(TF.label("%d / %d" % [have, need], 17, TF.GREEN if have >= need else TF.RED))
		_rd_ing.add_child(row)
	var ok := _station_ok(r)
	_rd_craft.disabled = not (ok and player.inv.can_craft(r))
	var five := ok
	for k in r.in:
		if player.inv.count(k) < int(r.in[k]) * 5:
			five = false
	_rd_craft5.disabled = not five


func _craft(times: int) -> void:
	if _sel_recipe < 0:
		return
	var r: Dictionary = Reg.recipes[_sel_recipe]
	var made := 0
	for t in times:
		if _station_ok(r) and player.inv.craft(r):
			made += 1
	if made > 0:
		Game.notify_crafted(r.out, int(r.get("n", 1)) * made)
		UiAnim.flash(_rd_icon, Color(0.6, 2.0, 1.0))
		UiAnim.bounce(_rd_icon, 1.25)


# ---------------------------------------------------------------- suit / quests

func _build_suit() -> Control:
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_suit_box = VBoxContainer.new()
	_suit_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suit_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_suit_box)
	return scroll


func _build_quests() -> Control:
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_quest_box = VBoxContainer.new()
	_quest_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_quest_box)
	return scroll


func _refresh_suit() -> void:
	for c in _suit_box.get_children():
		c.queue_free()
	var st := player.stats
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	_suit_box.add_child(top)
	var sp := SuitPreview.new()
	sp.custom_minimum_size = Vector2(220, 260)
	sp.set_def(Game.equipped_def("suit"))
	top.add_child(sp)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	tv.add_child(TF.label(Game.equipped_def("suit").get("name", ""), 24, TF.AMBER))
	var sdesc := TF.label(Game.equipped_def("suit").get("desc", ""), 15, TF.DIM)
	sdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sdesc.custom_minimum_size.x = 420
	tv.add_child(sdesc)
	tv.add_child(TF.label("Change your look in the Stellar Store on the title screen.", 14, TF.DIM))
	_suit_box.add_child(TF.label("EXOSUIT STATUS", 22, TF.CYAN))
	for b in [["Health", st.hp, st.max_hp, Color(1, 0.33, 0.4)], ["Oxygen", st.o2, st.max_o2, TF.CYAN], ["Energy", st.energy, st.max_energy, Color(1, 0.82, 0.25)], ["Nutrition", st.food, 100.0, TF.GREEN], ["Radiation", st.rad, 100.0, Color(0.7, 1, 0.3)]]:
		var row := HBoxContainer.new()
		var l := TF.label(b[0], 18, b[3])
		l.custom_minimum_size.x = 140
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = b[2]
		bar.value = b[1]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(380, 24)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_stylebox_override("fill", TF.bar_fill(b[3]))
		row.add_child(bar)
		row.add_child(TF.label("%d / %d" % [int(b[1]), int(b[2])], 17))
		_suit_box.add_child(row)
	_suit_box.add_child(TF.label("Body temperature %+.0f °C   ·   XP %d   ·   Tool tier %d" % [st.body_temp, player.xp, int(player.tool_stats().tier)], 17, TF.DIM))
	_suit_box.add_child(TF.label("UPGRADES", 22, TF.AMBER))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	_suit_box.add_child(grid)
	for u in [["o2", "suit_o2"], ["thermal", "suit_thermal"], ["rad", "suit_rad"], ["jet", "suit_jet"], ["armor", "suit_armor"]]:
		var card := _card()
		var v := VBoxContainer.new()
		card.add_child(v)
		var ic := TextureRect.new()
		ic.texture = Reg.icon(u[1])
		ic.custom_minimum_size = Vector2(64, 64)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var have := st.upgrades.has(u[0])
		ic.modulate = Color.WHITE if have else Color(1, 1, 1, 0.3)
		v.add_child(ic)
		var l := TF.label(Reg.item_label(u[1]), 15, TF.GREEN if have else TF.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 150
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		v.add_child(TF.label("INSTALLED" if have else "not installed", 13, TF.GREEN if have else TF.DIM))
		grid.add_child(card)
	if evolution != null:
		_suit_box.add_child(TF.label("PLANET", 22, TF.GREEN))
		_suit_box.add_child(TF.label(evolution.summary(), 17, TF.TEXT))


func _reward_row(rewards: Array, xp: int) -> HBoxContainer:
	var rw := HBoxContainer.new()
	rw.add_child(TF.label("REWARD", 14, TF.GREEN))
	for r in rewards:
		var ic := TextureRect.new()
		ic.texture = Reg.icon(r[0])
		ic.custom_minimum_size = Vector2(30, 30)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rw.add_child(ic)
		rw.add_child(TF.label("%s ×%d" % [Reg.item_label(r[0]), int(r[1])], 15))
	if xp > 0:
		rw.add_child(TF.label("  +%d XP" % xp, 15, TF.AMBER))
	return rw


func _progress_bar(gp: Vector2i, col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var bar := ProgressBar.new()
	bar.max_value = maxi(gp.y, 1)
	bar.value = gp.x
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("fill", TF.bar_fill(col))
	row.add_child(bar)
	row.add_child(TF.label("%d / %d" % [gp.x, gp.y], 15, col))
	return row


func _refresh_quests() -> void:
	for c in _quest_box.get_children():
		c.queue_free()
	if quests == null:
		return
	var total := Reg.quests.size()
	var done_n := mini(quests.index, total)
	var head := HBoxContainer.new()
	_quest_box.add_child(head)
	var ht := TF.label("MAIN STORY", 22, TF.AMBER)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	head.add_child(TF.label("%d / %d directives" % [done_n, total], 16, TF.DIM))
	var overall := ProgressBar.new()
	overall.max_value = total
	overall.value = done_n
	overall.show_percentage = false
	overall.custom_minimum_size.y = 8
	overall.add_theme_stylebox_override("fill", TF.bar_fill(TF.AMBER))
	_quest_box.add_child(overall)
	var q := quests.current()
	if q.is_empty():
		_quest_box.add_child(TF.label("The story is complete. The stars are yours.", 19, TF.GREEN))
	else:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", TF.box(Color(0.09, 0.07, 0.03, 0.95), TF.AMBER, 14, 2, 16))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		pc.add_child(v)
		v.add_child(TF.label("CHAPTER " + quests.chapter_name(q).to_upper(), 14, TF.AMBER))
		v.add_child(TF.label("▶ " + q.title, 24, TF.TEXT))
		if q.has("story"):
			var st := TF.label("%s: “%s”" % [q.get("speaker", "ECHO"), q.story], 16, Color(0.75, 0.85, 1.0))
			st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(st)
		var obj := TF.label("OBJECTIVE  ·  " + q.text, 17, TF.TEXT)
		obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(obj)
		v.add_child(_progress_bar(quests.goal_progress(q, quests.progress), TF.AMBER))
		v.add_child(_reward_row(q.get("reward", []), int(q.get("xp", 0))))
		_quest_box.add_child(pc)
		UiAnim.pop_in(pc, 0.05, 0.97)
	# side jobs
	var sh := TF.label("SIDE JOBS", 22, TF.CYAN)
	_quest_box.add_child(sh)
	if quests.side.is_empty():
		var hint := TF.label("No active jobs. Talk to survivors (aim at them and tap USE) to pick up work. The trader Ossa waits at Haven Outpost on Verdania.", 16, TF.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_quest_box.add_child(hint)
	for sid in quests.side:
		var sq: Dictionary = Reg.side_quests.get(sid, {})
		if sq.is_empty():
			continue
		var ready := quests.side_complete(sid)
		var giver: Dictionary = Reg.npcs.get(sq.giver, {})
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", TF.box(Color(0.05, 0.08, 0.12, 0.95), TF.GREEN if ready else TF.LINE, 12, 2, 14))
		var v := VBoxContainer.new()
		pc.add_child(v)
		v.add_child(TF.label(("✔ READY TO TURN IN  ·  " if ready else "") + sq.title, 19, TF.GREEN if ready else TF.TEXT))
		v.add_child(TF.label("for %s (%s, %s)" % [giver.get("name", "?"), giver.get("role", ""), Reg.planets.get(giver.get("planet", ""), {}).get("name", "")], 14, TF.AMBER))
		var t := TF.label(sq.text, 15, TF.DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		v.add_child(_progress_bar(quests.goal_progress(sq, int(quests.side[sid].progress)), TF.GREEN if ready else TF.CYAN))
		v.add_child(_reward_row(sq.get("reward", []), int(sq.get("xp", 0))))
		_quest_box.add_child(pc)
	# bestiary
	_quest_box.add_child(TF.label("BESTIARY  ·  hunt elites (★) for 4× rare drop chance", 22, Color(0.77, 0.54, 1.0)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_quest_box.add_child(grid)
	for cid in Reg.creatures:
		var cd: Dictionary = Reg.creatures[cid]
		var entry: Dictionary = quests.bestiary.get(cid, {})
		var seen := not entry.is_empty()
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", TF.box(Color(0.05, 0.05, 0.12, 0.92), Color.html(cd.c[2]) if seen else Color(1, 1, 1, 0.06), 12, 1, 12))
		var v := VBoxContainer.new()
		pc.add_child(v)
		var hd := HBoxContainer.new()
		v.add_child(hd)
		var sw := ColorRect.new()
		sw.color = Color.html(cd.c[0]) if seen else Color(0.15, 0.15, 0.2)
		sw.custom_minimum_size = Vector2(22, 22)
		hd.add_child(sw)
		var nm := TF.label(cd.name if seen else "??? unknown species", 18, TF.TEXT if seen else TF.DIM)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.add_child(nm)
		if seen:
			hd.add_child(TF.label("%d defeated" % int(entry.get("kills", 0)), 14, TF.DIM))
			v.add_child(TF.label("%s · %d HP · %s" % [cd.behavior.capitalize(), int(cd.hp), "boss" if cd.get("boss", false) else ("flies" if cd.get("fly", false) else "ground")], 14, TF.DIM))
		var drops := HBoxContainer.new()
		v.add_child(drops)
		for r in cd.get("rare", []):
			var found: bool = entry.get("drops", {}).has(r[0])
			var ic := TextureRect.new()
			ic.texture = Reg.icon(r[0])
			ic.custom_minimum_size = Vector2(30, 30)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.modulate = Color.WHITE if found else Color(0, 0, 0, 0.7)
			drops.add_child(ic)
			var chance := float(r[1]) * 100.0
			drops.add_child(TF.label(("%s %s%%" % [Reg.item_label(r[0]), str(snappedf(chance, 0.1))]) if found else "??? %s%%" % str(snappedf(chance, 0.1)), 13, Reg.rarity_color(r[0]) if found else TF.DIM))
		grid.add_child(pc)
	# history
	if done_n > 0:
		_quest_box.add_child(TF.label("COMPLETED", 18, TF.GREEN))
		var last_ch := -1
		for i in done_n:
			var dq: Dictionary = Reg.quests[i]
			if int(dq.chapter) != last_ch:
				last_ch = int(dq.chapter)
				_quest_box.add_child(TF.label(quests.chapter_name(dq), 14, TF.DIM))
			_quest_box.add_child(TF.label("   ✔ " + dq.title, 16, Color(0.6, 0.85, 0.65)))


# ---------------------------------------------------------------- open/close

func open(p: Player, st: Array, q: Quests = null, evo: Evolution = null) -> void:
	player = p
	quests = q
	evolution = evo
	stations = st
	_sel = -1
	if not player.inv.changed.is_connected(_mark_dirty):
		player.inv.changed.connect(_mark_dirty)
	var names := []
	for s in stations:
		names.append(Reg.item_label(s))
	_station_lbl.text = "Stations in range: " + (", ".join(names) if not names.is_empty() else "none — hand recipes only")
	visible = true
	_layout()
	_set_tab(_tab, true)
	UiAnim.pop_in(_panel, 0.0, 0.92)


func _mark_dirty() -> void:
	_dirty = true


func _process(_dt: float) -> void:
	if visible and _dirty:
		_dirty = false
		_refresh_slots()
		_update_detail()
		if _tab == 1:
			_refresh_recipes()


func _set_tab(i: int, instant := false) -> void:
	_tab = i
	for k in _tabs.size():
		_tabs[k].set_pressed_no_signal(k == i)
		_pages[k].visible = k == i
	match i:
		0:
			_refresh_slots()
			_update_detail()
		1:
			_refresh_recipes()
		2:
			_refresh_suit()
		3:
			_refresh_quests()
	if not instant:
		UiAnim.slide_in(_pages[i], Vector2(24, 0), 0.0, 0.22)
		if player != null and player.sfx != null:
			player.sfx.play("ui", -6.0)


func _on_close() -> void:
	var tw := create_tween().set_parallel(true)
	_panel.pivot_offset = _panel.size * 0.5
	tw.tween_property(_panel, "scale", Vector2.ONE * 0.95, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		_panel.scale = Vector2.ONE
		closed.emit())

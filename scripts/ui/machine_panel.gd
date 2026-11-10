class_name MachinePanel
extends Control
## Interaction panel for machines: storage, power status, terraformer controls, launch pad
## with ship assembly and the star map.

signal closed
signal travel(planet_id: String)

const TF := preload("res://scripts/ui/theme_factory.gd")

var root: Node
var pos: Vector3i
var kind := ""
var _body: VBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 40
	panel.offset_bottom = -40
	add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	_title = TF.label("", 28, TF.CYAN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(TF.button("Close", _close, 140))
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)


func open(r: Node, p: Vector3i, block_id: int) -> void:
	root = r
	pos = p
	kind = Reg.block_def(block_id).get("machine", "")
	_title.text = Reg.block_def(block_id).label.to_upper()
	visible = true
	_refresh()


func _close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	var m: Machines = root.machines
	var pw := "Grid: %+.0f kW generation, %.0f kW demand, battery %.0f / %.0f" % [m.gen, m.use, m.battery, m.capacity]
	_body.add_child(TF.label(pw + ("" if m.powered else "   ⚠ NO POWER"), 18, TF.GREEN if m.powered else TF.RED))
	match kind:
		"crate", "hydro", "miner", "smelter", "refinery":
			_storage_ui()
		"terraformer":
			_terraform_ui()
		"launchpad":
			_ship_ui()
		"beacon":
			_body.add_child(_para("Colony beacon. Planet status:\n" + root.evolution.summary()))
		_:
			var info := {
				"solar": "Generates up to 6 kW in daylight.",
				"battery": "Stores 400 kWs per bank. Keeps machines running at night.",
				"reactor": "Fusion reactor: 40 kW, day and night.",
				"o2": "Breathable bubble (radius 10) while powered.",
				"heater": "Keeps you warm within 8 blocks while powered.",
				"medbay": "You are reconstructed here if your suit fails.",
			}
			_body.add_child(_para(info.get(kind, "Machine.")))


func _para(t: String) -> Label:
	var l := TF.label(t, 19, TF.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _storage_ui() -> void:
	var m: Machines = root.machines
	var desc := {
		"crate": "Storage crate.",
		"hydro": "Grows Hydro Veggies every %d s while powered." % int(Machines.HYDRO_TIME),
		"miner": "Its drone mines ore within 12 blocks every %d s while powered." % int(Machines.MINER_TIME),
		"smelter": "Load ore chunks; it smelts 2 chunks into 1 ingot every %d s while powered. Also a crafting station." % int(Machines.SMELT_TIME),
		"refinery": "Crafting station for refined materials (open BAG nearby).",
	}
	_body.add_child(_para(desc.get(kind, "")))
	var slots := 18 if kind == "crate" else (6 if kind == "hydro" else 12)
	var inv := m.storage(pos, slots)
	var grid := GridContainer.new()
	grid.columns = 9
	_body.add_child(grid)
	for s in inv:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Reg.icon(s.id) if s != null else null
		b.text = str(s.n) if s != null and s.n > 1 else ""
		b.disabled = true
		grid.add_child(b)
	var row := HBoxContainer.new()
	_body.add_child(row)
	row.add_child(TF.button("Take All", _take_all, 200))
	if kind == "smelter" or kind == "crate":
		row.add_child(TF.button("Deposit Ore" if kind == "smelter" else "Deposit All", _deposit, 220))


func _take_all() -> void:
	var n: int = root.machines.take_all(pos, root.player.inv)
	root.sfx.play("pickup")
	root.hud.toast("Took %d items" % n, TF.GREEN)
	_refresh()


func _deposit() -> void:
	var m: Machines = root.machines
	var inv: Inventory = root.player.inv
	var moved := 0
	for i in Inventory.SIZE:
		var s = inv.slots[i]
		if s == null or i == root.player.selected:
			continue
		var it := Reg.item(s.id)
		if kind == "smelter" and m._smelt_out(s.id) == "":
			continue
		if kind == "crate" and it.get("type", "") in ["tool", "weapon"]:
			continue
		var left := m.store(pos, s.id, int(s.n))
		moved += int(s.n) - left
		inv.remove_at(i, int(s.n) - left)
	root.hud.toast("Deposited %d items" % moved, TF.CYAN)
	_refresh()


func _terraform_ui() -> void:
	var evo: Evolution = root.evolution
	_body.add_child(_para("Planet Evolution — " + root.planet.name))
	for k in [["atmo", "Atmosphere", Color(0.5, 0.85, 1)], ["water", "Water", Color(0.3, 0.6, 1)], ["life", "Life", Color(0.5, 1, 0.5)], ["pollution", "Pollution", Color(0.8, 0.6, 0.5)]]:
		var row := HBoxContainer.new()
		_body.add_child(row)
		var l := TF.label(k[1], 20, k[2])
		l.custom_minimum_size.x = 160
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(500, 26)
		bar.max_value = 100
		bar.value = float(evo.stats[k[0]]) * 100.0
		bar.add_theme_stylebox_override("fill", TF.bar_fill(k[2]))
		row.add_child(bar)
	_body.add_child(_para("Powered terraformers raise atmosphere, then water. Life needs a Gaia Seed Vault. Catalysts speed everything up. At high life the ground around each terraformer turns to soil and grass. Catalyst boost: +%d%%" % int(float(evo.stats.catalyst) * 100)))
	var row2 := HBoxContainer.new()
	_body.add_child(row2)
	row2.add_child(TF.button("Insert Atmo Catalyst", _insert_catalyst, 300))
	row2.add_child(TF.button("Insert Gaia Seed Vault", _insert_seed, 320))


func _insert_catalyst() -> void:
	var evo: Evolution = root.evolution
	if root.player.inv.remove("atmo_seed", 1):
		evo.stats.catalyst = minf(3.0, float(evo.stats.catalyst) + 0.5)
		root.sfx.play("craft")
	else:
		root.hud.toast("Need an Atmo Catalyst (Refinery)", TF.RED)
	_refresh()


func _insert_seed() -> void:
	var evo: Evolution = root.evolution
	if evo.stats.seeded:
		root.hud.toast("Already seeded", TF.DIM)
	elif root.player.inv.remove("bio_seed", 1):
		evo.stats.seeded = true
		root.sfx.play("quest")
	else:
		root.hud.toast("Need a Gaia Seed Vault (Refinery)", TF.RED)
	_refresh()


func _ship_ui() -> void:
	var ship: Dictionary = root.ship
	var inv: Inventory = root.player.inv
	var parts := [["hull", "ship_hull_kit", "Hull frame"], ["nav", "nav_computer", "Nav computer"]]
	_body.add_child(_para("Starship assembly. Install parts from your inventory. Engine tier decides which worlds you can reach. Each jump burns 1 Hydrazine Fuel Cell."))
	var row := HBoxContainer.new()
	_body.add_child(row)
	for p in parts:
		var have: bool = ship.get(p[0], false)
		var b := TF.button(("✔ " if have else "Install ") + p[2], _install_part.bind(p[0], p[1]), 260)
		b.disabled = have
		row.add_child(b)
	var tier := int(ship.get("engine", 0))
	row.add_child(TF.button("Engine tier %d — install better engine" % tier, _install_engine, 420))
	var ready: bool = ship.get("hull", false) and ship.get("nav", false) and tier > 0
	if ready:
		root.quests.event("ship", "")
	_body.add_child(TF.label("STAR MAP  ·  fuel cells: %d" % inv.count("fuel_cell"), 24, TF.AMBER))
	for pid in Reg.planet_order:
		var p: Dictionary = Reg.planets[pid]
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", TF.box(Color(0.07, 0.08, 0.16, 0.9), Color.html(p.color), 10, 2, 10))
		_body.add_child(pc)
		var h := HBoxContainer.new()
		pc.add_child(h)
		var sw := ColorRect.new()
		sw.color = Color.html(p.color)
		sw.custom_minimum_size = Vector2(36, 36)
		h.add_child(sw)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var here: bool = pid == root.planet.id
		v.add_child(TF.label("%s   (tier %d)%s" % [p.name, int(p.tier), "   ← you are here" if here else ""], 21, TF.TEXT))
		var info := TF.label("%s  Gravity %.1f · %+d°C · O2 %d%% · Radiation %d%%" % [p.desc, float(p.gravity), int(p.temp), int(float(p.o2) * 100), int(float(p.rad) * 100)], 15, TF.DIM)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(info)
		var tb := TF.button("Jump", _jump.bind(pid), 130)
		tb.disabled = here or not ready or tier < int(p.tier)
		h.add_child(tb)


func _install_part(key: String, item: String) -> void:
	if root.player.inv.remove(item, 1):
		root.ship[key] = true
		root.sfx.play("craft")
	else:
		root.hud.toast("Need: " + Reg.item_label(item), TF.RED)
	_refresh()


func _install_engine() -> void:
	var tier := int(root.ship.get("engine", 0))
	var ok := false
	for e in [["ship_engine_3", 3], ["ship_engine_2", 2], ["ship_engine", 1]]:
		if int(e[1]) > tier and root.player.inv.remove(e[0], 1):
			root.ship["engine"] = e[1]
			root.sfx.play("craft")
			ok = true
			break
	if not ok:
		root.hud.toast("No better engine in inventory (Assembler/Refinery)", TF.RED)
	_refresh()


func _jump(pid: String) -> void:
	if root.player.inv.remove("fuel_cell", 1):
		travel.emit(pid)
	else:
		root.hud.toast("Need a Hydrazine Fuel Cell (Assembler)", TF.RED)

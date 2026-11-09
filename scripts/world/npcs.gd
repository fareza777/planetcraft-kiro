class_name Npcs
extends Node3D
## Planet NPCs (data/npcs.json): builds Haven Outpost on Verdania and survivor camps on other
## worlds, spawns animated humanoid NPCs with quest markers.

const TF := preload("res://scripts/ui/theme_factory.gd")


class Npc:
	extends Node3D
	var def: Dictionary
	var head: Node3D
	var arm_r: Node3D
	var torso: Node3D
	var label: Label3D
	var marker: Label3D
	var t := randf() * 10.0
	var waved := false
	var _wave := 0.0

	func build(d: Dictionary) -> void:
		def = d
		var suit := Color.html(d.get("suit", "#5e6777"))
		var visor := Color.html(d.get("visor", "#4fe3ff"))
		var dark := suit.darkened(0.45)
		torso = Node3D.new()
		torso.position = Vector3(0, 0.95, 0)
		add_child(torso)
		_box(torso, Vector3(0.5, 0.6, 0.3), Vector3(0, 0.05, 0), suit)
		_box(torso, Vector3(0.52, 0.12, 0.32), Vector3(0, -0.22, 0), dark)
		_box(torso, Vector3(0.36, 0.42, 0.18), Vector3(0, 0.05, 0.22), dark)
		_box(torso, Vector3(0.08, 0.08, 0.02), Vector3(0.14, 0.18, -0.16), visor, true)
		head = Node3D.new()
		head.position = Vector3(0, 0.42, 0)
		torso.add_child(head)
		_box(head, Vector3(0.42, 0.4, 0.42), Vector3(0, 0.15, 0), suit.lightened(0.15))
		_box(head, Vector3(0.34, 0.16, 0.04), Vector3(0, 0.17, -0.22), visor, true)
		_box(head, Vector3(0.06, 0.18, 0.06), Vector3(0.16, 0.44, 0.05), dark)
		for side in [-1, 1]:
			var arm := Node3D.new()
			arm.position = Vector3(0.33 * side, 0.28, 0)
			torso.add_child(arm)
			_box(arm, Vector3(0.16, 0.55, 0.16), Vector3(0, -0.25, 0), suit)
			_box(arm, Vector3(0.17, 0.12, 0.17), Vector3(0, -0.52, 0), dark)
			if side == 1:
				arm_r = arm
			var leg := Node3D.new()
			leg.position = Vector3(0.13 * side, 0.7, 0)
			add_child(leg)
			_box(leg, Vector3(0.2, 0.7, 0.22), Vector3(0, -0.35, 0), dark)
			_box(leg, Vector3(0.22, 0.12, 0.3), Vector3(0, -0.65, -0.04), suit.darkened(0.6))
		label = Label3D.new()
		label.text = "%s\n%s" % [d.name, d.role]
		label.font_size = 40
		label.outline_size = 10
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.9, 0.95, 1.0)
		label.position = Vector3(0, 2.35, 0)
		add_child(label)
		marker = Label3D.new()
		marker.font_size = 110
		marker.outline_size = 16
		marker.pixel_size = 0.006
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = Color(1.0, 0.75, 0.2)
		marker.position = Vector3(0, 2.9, 0)
		add_child(marker)

	func _box(p: Node3D, sz: Vector3, pos: Vector3, c: Color, glow := false) -> void:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = sz
		mi.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		if glow:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = c * 1.4
		mi.material_override = m
		mi.position = pos
		p.add_child(mi)

	func tick(dt: float, player_pos: Vector3, mark: String) -> void:
		t += dt
		torso.position.y = 0.95 + sin(t * 1.8) * 0.015
		var to := player_pos - global_position
		var d := to.length()
		if d < 9.0:
			var yaw := atan2(-to.x, -to.z) - rotation.y
			head.rotation.y = lerp_angle(head.rotation.y, clampf(wrapf(yaw, -PI, PI), -1.1, 1.1), dt * 4.0)
			if not waved and d < 6.0:
				waved = true
				_wave = 1.6
		else:
			head.rotation.y = lerp_angle(head.rotation.y, sin(t * 0.3) * 0.5, dt * 1.5)
			if d > 14.0:
				waved = false
		if _wave > 0.0:
			_wave -= dt
			arm_r.rotation.x = -2.6
			arm_r.rotation.z = sin(t * 12.0) * 0.4
		else:
			arm_r.rotation.x = lerpf(arm_r.rotation.x, sin(t * 1.8) * 0.05, dt * 5.0)
			arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.0, dt * 5.0)
		marker.text = mark
		marker.modulate = Color(0.48, 1.0, 0.6) if mark == "?" else Color(1.0, 0.75, 0.2)
		marker.position.y = 2.9 + sin(t * 3.0) * 0.08


var world: VoxelWorld
var player: Player
var planet: Dictionary
var quests: Quests
var list: Array[Npc] = []
var site := Vector3.ZERO
var built := false
var _pending := true


func setup(w: VoxelWorld, p: Player, pl: Dictionary, q: Quests, st: Dictionary, spawn: Vector3) -> void:
	world = w
	player = p
	planet = pl
	quests = q
	built = st.get("outpost_built", false)
	if st.has("outpost"):
		site = st.outpost
	elif pl.id == "verdania":
		site = spawn + Vector3(34, 0, 26)
	else:
		site = spawn + Vector3(9, 0, 7)


func has_npcs() -> bool:
	for n in Reg.npcs.values():
		if n.planet == planet.id:
			return true
	return false


func _process(dt: float) -> void:
	if world == null or not has_npcs():
		return
	if _pending:
		if not world.has_chunk_at(site) or world.chunks.get(Vector2i(floori(site.x) >> 4, floori(site.z) >> 4)) == null:
			return
		var top := world.column_top(floori(site.x), floori(site.z))
		if top <= 0:
			return
		_pending = false
		if not built:
			site.y = top + 1
			_build_site()
			built = true
		elif site.y <= 0:
			site.y = top + 1
		_spawn_npcs()
	var pp := player.global_position
	for n in list:
		n.tick(dt, pp, quests.npc_marker(n.def.id) if quests != null else "")


func _build_site() -> void:
	var c := Vector3i(floori(site.x), floori(site.y), floori(site.z))
	var floor_id := Reg.block("station_floor")
	var wall := Reg.block("metal_plate")
	var glass := Reg.block("glass")
	var big: bool = planet.id == "verdania"
	var rx := 7 if big else 3
	var rz := 5 if big else 3
	for dz in range(-rz, rz + 1):
		for dx in range(-rx, rx + 1):
			for y in range(c.y - 4, c.y):
				world.set_block(c.x + dx, y, c.z + dz, floor_id if y == c.y - 1 else Reg.block("hull"))
			for y in range(c.y, c.y + 6):
				var id := world.get_block(c.x + dx, y, c.z + dz)
				if id > 0:
					world.set_block(c.x + dx, y, c.z + dz, 0)
	if big:
		for dz in range(-rz, rz + 1):
			for dx in range(-rx, rx + 1):
				var edge := absi(dx) == rx or absi(dz) == rz
				var door := dz == -rz and absi(dx) <= 1
				if edge and not door:
					world.set_block(c.x + dx, c.y, c.z + dz, wall)
					world.set_block(c.x + dx, c.y + 1, c.z + dz, glass if (dx + dz) % 3 != 0 else wall)
					world.set_block(c.x + dx, c.y + 2, c.z + dz, wall)
		for dz in range(-rz, rz + 1):
			for dx in range(-rx, rx + 1):
				if absi(dx) < rx and absi(dz) < rz and (absi(dx) + absi(dz)) % 4 == 0:
					world.set_block(c.x + dx, c.y + 3, c.z + dz, glass)
				elif absi(dx) <= rx and absi(dz) <= rz:
					world.set_block(c.x + dx, c.y + 3, c.z + dz, wall)
		for p in [Vector3i(-5, 0, 3), Vector3i(5, 0, 3), Vector3i(0, 2, 0)]:
			world.set_block(c.x + p.x, c.y + p.y, c.z + p.z, Reg.block("lamp"))
		world.set_block(c.x + 6, c.y, c.z - 4, Reg.block("crate"))
		world.set_block(c.x - 6, c.y, c.z - 4, Reg.block("hydro_tray"))
		# relay tower
		for y in range(0, 9):
			world.set_block(c.x + rx + 2, c.y + y, c.z + rz + 1, Reg.block("hull"))
		world.set_block(c.x + rx + 2, c.y + 9, c.z + rz + 1, Reg.block("beacon"))
	else:
		world.set_block(c.x + 2, c.y, c.z + 2, Reg.block("lamp"))
		world.set_block(c.x - 2, c.y, c.z + 2, Reg.block("crate"))


func _spawn_npcs() -> void:
	for d in Reg.npcs.values():
		if d.planet != planet.id:
			continue
		var n := Npc.new()
		add_child(n)
		n.build(d)
		var off: Array = d.get("offset", [0, 0, 0])
		n.global_position = site + Vector3(float(off[0]), 0.0, float(off[2]))
		n.rotation.y = PI
		list.append(n)


func ray_npc(origin: Vector3, dir: Vector3, reach: float) -> Npc:
	for n in list:
		var c := n.global_position + Vector3(0, 1.1, 0)
		var oc := c - origin
		var t := oc.dot(dir)
		if t > 0.0 and t < reach and (oc - dir * t).length() < 0.75:
			return n
	return null


func position_of(npc_id: String) -> Variant:
	for n in list:
		if n.def.id == npc_id:
			return n.global_position
	if planet.id == Reg.npcs.get(npc_id, {}).get("planet", ""):
		return site
	return null


func save_data() -> Dictionary:
	return {"outpost": site, "outpost_built": built}

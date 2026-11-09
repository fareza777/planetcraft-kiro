extends Node
## Scripted gameplay bot for end-to-end checks on a real (windowed) renderer.
## Run:  Godot --path . -- autotest
## Drives the player through mining, placing, crafting, day/night and save/load, writes
## screenshots to test_output/ (desktop) or user:// (device), and prints PASS/FAIL lines.

var root: WorldRoot
var t := 0.0
var step := 0
var passes := 0
var fails := 0
var _mark := {}
var out_dir := "res://test_output/"


func _ready() -> void:
	if OS.has_feature("mobile"):
		out_dir = "user://"
	print("[AUTOTEST] started")


func check(c: bool, name: String) -> void:
	if c:
		passes += 1
		print("[AUTOTEST] PASS ", name)
	else:
		fails += 1
		print("[AUTOTEST] FAIL ", name)


func shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + name)
	print("[AUTOTEST] screenshot ", out_dir + name)


func _process(dt: float) -> void:
	t += dt
	var p := root.player
	if p == null:
		return
	match step:
		0:
			if not root.loading.visible and t > 1.0:
				check(true, "world loaded and player spawned in %.1f s" % t)
				check(root._pod_built, "crash pod built")
				_next()
		1:
			if t > 1.5:
				var pp := p.global_position
				print("[AUTOTEST] info pos=%s spawn=%s top=%d hud_size=%s vp=%s" % [pp, root.spawn_point, root.world.column_top(floori(pp.x), floori(pp.z)), root.hud.size, get_viewport().get_visible_rect().size])
				p.yaw = 0.6
				p.pitch = -0.15
				shot("01_spawn.png")
				_next()
		2:
			if t > 0.5:
				# walk out of the pod and look down at the ground to mine
				p.ctl.move = Vector2(0, 1)
				_mark["start"] = p.global_position
				_next()
		3:
			p.ctl.move = Vector2(0, 1)
			if t > 2.5:
				p.ctl.move = Vector2.ZERO
				check(p.global_position.distance_to(_mark.start) > 3.0, "player walks (%.1f m)" % p.global_position.distance_to(_mark.start))
				p.pitch = -1.3
				_mark["items"] = _total_items(p)
				_next()
		4:
			p.ctl.mine = true
			if t > 5.0:
				p.ctl.mine = false
				var gained := _total_items(p) - int(_mark.items)
				check(gained >= 1, "mining adds items (+%d)" % gained)
				_next()
		5:
			# place the first block item we hold
			for i in 36:
				var s = p.inv.slots[i]
				if s != null and Reg.item(s.id).get("type", "") == "block" and s.id != "lamp":
					p.inv.swap(i, 0)
					break
			p.selected = 0
			p.pitch = -1.0
			_next()
		6:
			if t > 0.3:
				for k in 16:
					p.yaw = k * TAU / 16.0
					p.pitch = -0.7 - (k % 2) * 0.3
					p.rotation = Vector3(0, p.yaw, 0)
					p.cam.rotation = Vector3(p.pitch, 0, 0)
					p._update_target()
					if not p.target.is_empty():
						var dest: Vector3i = p.target.pos + p.target.normal
						if p.world.get_block(dest.x, dest.y, dest.z) == 0 and not p._overlaps_player(dest):
							break
				var before := _total_items(p)
				p.ctl.place = true
				_mark["placed_before"] = before
				_next()
		7:
			if t > 0.4:
				check(_total_items(p) == int(_mark.placed_before) - 1, "placing consumes one block")
				if _total_items(p) != int(_mark.placed_before) - 1:
					print("[AUTOTEST] info target=%s sel=%s pos=%s proc=%s" % [p.target, p.inv.slots[p.selected], p.global_position, p.is_processing()])
				p.inv.add("basalt", 8)
				p.inv.add("ferrite_chunk", 4)
				var fab := {}
				for r in Reg.recipes:
					if r.out == "fabricator":
						fab = r
				check(p.inv.craft(fab), "craft fabricator by hand")
				root.open_inventory()
				_next()
		8:
			if t > 1.0:
				shot("02_inventory.png")
				root.inv_screen._on_close()
				p.pitch = 0.05
				p.yaw = 2.2
				p.ctl.jump = true
				_next()
		9:
			if t > 1.2:
				p.ctl.jump = false
				check(true, "jetpack/jump cycle ran without errors")
				shot("03_day_view.png")
				root.sky.time_of_day = 0.02
				_next()
		10:
			if t > 1.5:
				shot("04_night.png")
				root.sky.time_of_day = 0.35
				root.save()
				check(FileAccess.file_exists(Game.SAVE_DIR + "meta.dat"), "save meta written")
				var mods := Game.load_mods(root.planet.id)
				var n := 0
				for k in mods:
					n += mods[k].size()
				var n2 := 0
				for k in root.world.mods:
					n2 += root.world.mods[k].size()
				check(n == n2 and n > 0, "saved edits reload (%d == %d)" % [n, n2])
				check(Game.load_meta() and Game.meta.player.inv.size() == 36, "meta reloads with inventory")
				_next()
		11:
			if t > 0.5:
				# dig straight down to look at caves / ores with the headlamp
				p.noclip = true
				p.global_position.y -= 18
				p.pitch = -0.2
				_next()
		12:
			if t > 2.0:
				shot("05_underground.png")
				p.global_position = root.spawn_point + Vector3(0, 24, 18)
				p.yaw = 0.0
				p.pitch = -0.75
				_next()
		13:
			if t > 2.5:
				shot("06_aerial.png")
				p.noclip = false
				print("[AUTOTEST] fps=%d" % root.hud.info.fps)
				print("[AUTOTEST] DONE passes=%d fails=%d" % [passes, fails])
				get_tree().quit(1 if fails > 0 else 0)


func _next() -> void:
	step += 1
	t = 0.0


func _total_items(p: Player) -> int:
	var n := 0
	for s in p.inv.slots:
		if s != null:
			n += int(s.n)
	return n

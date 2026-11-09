extends Node
## Headless test suite. Run:
##   Godot --headless --path . res://tests/test_scene.tscn
## Exit code 0 = all passed. Writes texture previews to test_output/ for manual review.

const Gen := preload("res://scripts/voxel/terrain_generator.gd")
const Mesher := preload("res://scripts/voxel/mesher.gd")

var failures := 0
var passes := 0
var world: VoxelWorld
var frames := 0
var phase := 0
var t_start := 0


func check(cond: bool, name: String) -> void:
	if cond:
		passes += 1
		print("  PASS ", name)
	else:
		failures += 1
		print("  FAIL ", name)


func _ready() -> void:
	print("== PlanetCraft headless tests ==")
	_test_registry()
	_test_generator()
	_test_mesher()
	_dump_textures()
	if Engine.has_singleton("Game") or get_node_or_null("/root/Game") != null:
		_test_game_logic()
	_start_world_test()


func _test_registry() -> void:
	print("[registry]")
	check(Reg.blocks.size() > 50, "blocks loaded (%d)" % Reg.blocks.size())
	check(Reg.tile_array != null and Reg.tile_array.get_layers() == Reg.tile_defs.size(), "texture array layers = tiles (%d)" % Reg.tile_defs.size())
	check(Reg.items.has("multitool_1") and Reg.items.has("basalt"), "items include tools and blocks")
	var missing := []
	for r in Reg.recipes:
		if not Reg.items.has(r.out):
			missing.append(r.out)
		for k in r.in:
			if not Reg.items.has(k):
				missing.append(k)
	check(missing.is_empty(), "all recipe items exist %s" % str(missing))
	var bad_drops := []
	for b in Reg.blocks:
		var d: String = b.get("drop", b.name)
		if b.name != "air" and d != "" and not Reg.items.has(d):
			bad_drops.append(b.name)
	check(bad_drops.is_empty(), "all block drops exist %s" % str(bad_drops))


func _test_generator() -> void:
	print("[generator]")
	for pid in Reg.planet_order:
		var p: Dictionary = Reg.planets[pid]
		var g1 := Gen.new(p, 12345)
		var g2 := Gen.new(p, 12345)
		var g3 := Gen.new(p, 999)
		var t0 := Time.get_ticks_usec()
		var a := g1.generate_chunk(3, -2, {})
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		var b := g2.generate_chunk(3, -2, {})
		var c := g3.generate_chunk(3, -2, {})
		var solid := 0
		for v in a:
			if v != 0:
				solid += 1
		check(a == b, "%s deterministic for same seed" % pid)
		check(a != c, "%s differs for other seed" % pid)
		check(solid > 500, "%s chunk has terrain (%d blocks, %.1f ms)" % [pid, solid, dt])


func _test_mesher() -> void:
	print("[structures & loot]")
	var gs := Gen.new(Reg.planets["verdania"], 31337)
	var found := {}
	for cz in range(-8, 8):
		for cx in range(-8, 8):
			var bb := gs.generate_chunk(cx, cz, {})
			for nm in ["obelisk_core", "salvage_crate", "hive_core", "shrine_altar", "ruin_cache"]:
				if bb.has(Reg.block(nm)):
					found[nm] = int(found.get(nm, 0)) + 1
	check(found.size() >= 3, "256 chunks contain several structure types %s" % str(found))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rolls := 0
	for i in 200:
		rolls += Reg.roll_loot("trial", rng).size()
	check(rolls == 800, "trial loot table rolls 4 items each time")
	check(Reg.rarity("stellar_shard") == "legendary" and Reg.store.size() >= 20, "rarity and store data loaded")
	print("[mesher]")
	var g := Gen.new(Reg.planets["verdania"], 4242)
	var cols := []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			cols.append(g.generate_chunk(dx, dz, {}))
	var t0 := Time.get_ticks_usec()
	var pd := Mesher.pad(cols)
	var res := Mesher.mesh_sections(pd, PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7]), Reg.kind, Reg.face_tiles, Reg.emissive, Reg.light_radius)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	var quads := 0
	var bad_wind := 0
	var checked := 0
	for sec in res:
		var layers: Array = sec.layers
		for l in 3:
			var arr: Array = layers[l]
			if arr.is_empty():
				continue
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			quads += idx.size() / 6
			if l == 0:
				for t in range(0, mini(idx.size(), 3000), 3):
					var cr := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
					checked += 1
					if cr.dot(n[idx[t]]) >= 0.0:
						bad_wind += 1
	check(quads > 100, "center chunk meshed: %d quads in %.1f ms" % [quads, dt])
	check(checked > 0 and bad_wind == 0, "clockwise front-face winding (%d/%d bad)" % [bad_wind, checked])


func _dump_textures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_output"))
	var n := Reg.tile_images.size()
	var colsn := 12
	var rows := int(ceil(n / float(colsn)))
	var sheet := Image.create_empty(colsn * 34, rows * 34, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in n:
		var img: Image = Reg.tile_images[i]
		sheet.blit_rect(img, Rect2i(0, 0, 32, 32), Vector2i((i % colsn) * 34 + 1, (i / colsn) * 34 + 1))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png("res://test_output/tiles.png")
	var ids: Array = Reg.item_order
	rows = int(ceil(ids.size() / float(colsn)))
	var isheet := Image.create_empty(colsn * 34, rows * 34, false, Image.FORMAT_RGBA8)
	isheet.fill(Color(0.16, 0.16, 0.2))
	for i in ids.size():
		var tex: Texture2D = Reg.icon(ids[i])
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		isheet.blend_rect(img, Rect2i(0, 0, 32, 32), Vector2i((i % colsn) * 34 + 1, (i / colsn) * 34 + 1))
	isheet.resize(isheet.get_width() * 3, isheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	isheet.save_png("res://test_output/icons.png")
	print("  info: wrote test_output/tiles.png and icons.png")


func _test_game_logic() -> void:
	var gl = get_node("/root/Game")
	if gl.has_method("run_self_tests"):
		print("[game logic]")
		for r in gl.run_self_tests():
			check(r[0], r[1])


func _start_world_test() -> void:
	print("[world streaming]")
	world = VoxelWorld.new()
	add_child(world)
	world.radius = 4
	world.setup(Reg.planets["verdania"], 777, {})
	world.focus = Vector3(8, 60, 8)
	t_start = Time.get_ticks_msec()
	phase = 1


func _process(_dt: float) -> void:
	if phase == 0:
		return
	frames += 1
	var elapsed := Time.get_ticks_msec() - t_start
	if phase == 1:
		if world.loaded_ratio() >= 1.0:
			print("  info: radius 4 loaded in %d ms, %d frames, gen avg %.1f ms, mesh avg %.1f ms" % [elapsed, frames,
				world.stats.gen_ms / maxf(world.stats.gen, 1), world.stats.mesh_ms / maxf(world.stats.mesh, 1)])
			check(true, "world streamed radius 4")
			var top := world.column_top(8, 8)
			check(top > 0, "column top found (%d)" % top)
			var hit := world.raycast(Vector3(8.5, 126, 8.5), Vector3.DOWN, 140)
			check(not hit.is_empty() and hit.pos.y >= top - 1, "raycast down hits surface")
			var before: int = world.chunks[Vector2i(0, 0)].version
			check(world.set_block(8, top + 1, 8, Reg.block("metal_plate")), "set_block places")
			check(world.get_block(8, top + 1, 8) == Reg.block("metal_plate"), "get_block reads placed block")
			check(world.mods.has(Vector2i(0, 0)) and world.chunks[Vector2i(0, 0)].version == before + 1, "edit recorded in mods")
			var ctop := world.column_top(15, 15)
			world.set_block(15, ctop, 15, 0)
			check(not world.chunks[Vector2i(1, 1)].dirty.is_empty() or not world.chunks[Vector2i(1, 0)].dirty.is_empty(), "border edit dirties neighbour")
			phase = 2
			t_start = Time.get_ticks_msec()
		elif elapsed > 60000:
			check(false, "world streamed radius 4 (timeout)")
			_finish()
	elif phase == 2:
		if world.pending_work() == 0 and world.chunks[Vector2i(0, 0)].dirty.is_empty():
			check(true, "remesh after edit completed in %d ms" % elapsed)
			# regeneration with mods keeps edits
			var g := Gen.new(Reg.planets["verdania"], 777)
			var b := g.generate_chunk(0, 0, world.mods[Vector2i(0, 0)])
			var top := world.column_top(8, 8)
			check(b[top + 128 * (8 + 16 * 8)] == Reg.block("metal_plate"), "mods re-applied on regeneration")
			_finish()
		elif elapsed > 20000:
			check(false, "remesh after edit (timeout)")
			_finish()


func _finish() -> void:
	phase = 0
	world.shutdown()
	print("== %d passed, %d failed ==" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)

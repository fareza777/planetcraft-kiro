extends Node
## Reg: loads every data-driven definition from res://data and builds lookup tables and
## generated textures. Read-only after _ready(), so worker threads may read its packed arrays.

const TextureFactory := preload("res://scripts/voxel/texture_factory.gd")
const DATA_DIR := "res://data/"

enum Kind { AIR, OPAQUE, CUTOUT, FLUID, PLANT }
const KIND_NAMES := {"air": Kind.AIR, "opaque": Kind.OPAQUE, "cutout": Kind.CUTOUT, "fluid": Kind.FLUID, "plant": Kind.PLANT}
# Face order used everywhere: +X, -X, +Y, -Y, +Z, -Z
const FACE_KEYS := ["side", "side", "top", "bottom", "side", "side"]

var tile_index: Dictionary = {}
var tile_defs: Array = []
var tile_images: Array[Image] = []
var tile_array: Texture2DArray
var tile_avg := PackedColorArray()

var blocks: Array = []
var block_ids: Dictionary = {}
var kind := PackedByteArray()
var solid := PackedByteArray()
var emissive := PackedByteArray()
var face_tiles := PackedInt32Array()
var hardness := PackedFloat32Array()
var tier := PackedByteArray()
var light_radius := PackedFloat32Array()

var items: Dictionary = {}
var item_order: Array = []
var recipes: Array = []
var planets: Dictionary = {}
var planet_order: Array = []
var creatures: Dictionary = {}
var quests: Array = []

var _icon_cache: Dictionary = {}


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_load_tiles()
	_load_blocks()
	_load_items()
	recipes = _read_json("recipes.json")
	for p in _read_json("planets.json"):
		planets[p.id] = p
		planet_order.append(p.id)
	if FileAccess.file_exists(DATA_DIR + "creatures.json"):
		for c in _read_json("creatures.json"):
			creatures[c.id] = c
	if FileAccess.file_exists(DATA_DIR + "quests.json"):
		quests = _read_json("quests.json")
	print("[Reg] loaded %d tiles, %d blocks, %d items, %d recipes, %d planets in %d ms" % [
		tile_defs.size(), blocks.size(), items.size(), recipes.size(), planets.size(), Time.get_ticks_msec() - t0])


func _read_json(file: String) -> Array:
	var text := FileAccess.get_file_as_string(DATA_DIR + file)
	var data = JSON.parse_string(text)
	if data == null:
		push_error("[Reg] failed to parse " + file)
		return []
	return data


func _load_tiles() -> void:
	tile_defs = _read_json("tiles.json")
	var by_name: Dictionary = {}
	for i in tile_defs.size():
		var def: Dictionary = tile_defs[i]
		tile_index[def.name] = i
		var base: Image = null
		if def.has("base") and by_name.has(def.base):
			base = by_name[def.base]
		var img: Image = TextureFactory.make_tile(def, i * 7919 + 13, base)
		by_name[def.name] = img
		tile_images.append(img)
	var mipped: Array[Image] = []
	for img in tile_images:
		var m: Image = img.duplicate()
		m.generate_mipmaps()
		mipped.append(m)
		var acc := Color(0, 0, 0, 0)
		var cnt := 0
		for y in range(0, 32, 2):
			for x in range(0, 32, 2):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					acc += c
					cnt += 1
		tile_avg.append(acc / maxf(cnt, 1) if cnt > 0 else Color(0.5, 0.5, 0.5))
	tile_array = Texture2DArray.new()
	var err := tile_array.create_from_images(mipped)
	if err != OK:
		push_error("[Reg] Texture2DArray creation failed: %d" % err)


func _tile(name: String) -> int:
	return tile_index.get(name, 0)


func _load_blocks() -> void:
	var defs := _read_json("blocks.json")
	var n := defs.size()
	kind.resize(256)
	solid.resize(256)
	emissive.resize(256)
	tier.resize(256)
	face_tiles.resize(256 * 6)
	hardness.resize(256)
	light_radius.resize(256)
	for id in n:
		var d: Dictionary = defs[id]
		d["id"] = id
		blocks.append(d)
		block_ids[d.name] = id
		var k: int = KIND_NAMES.get(d.get("kind", "opaque"), Kind.OPAQUE)
		kind[id] = k
		var default_solid := k == Kind.OPAQUE or k == Kind.CUTOUT
		solid[id] = 1 if d.get("solid", default_solid) else 0
		emissive[id] = 1 if d.get("emissive", false) else 0
		hardness[id] = float(d.get("hard", 1.0))
		tier[id] = int(d.get("tier", 0))
		light_radius[id] = float(d.get("light", 0.0))
		var tex: Dictionary = d.get("tex", {})
		for f in 6:
			var key: String = FACE_KEYS[f]
			var tname: String = tex.get(key, tex.get("all", tex.get("side", "basalt")))
			face_tiles[id * 6 + f] = _tile(tname)


func _load_items() -> void:
	# Every placeable block is also an item.
	for b in blocks:
		if b.name == "air" or not b.get("place", true):
			continue
		var it := {"id": b.name, "label": b.label, "type": "block", "block": b.id, "stack": 64}
		items[b.name] = it
		item_order.append(b.name)
	for it in _read_json("items.json"):
		if not it.has("stack"):
			it["stack"] = 64
		items[it.id] = it
		item_order.append(it.id)
	# Blocks with place=false can still drop as themselves when listed nowhere else.
	for b in blocks:
		var drop: String = b.get("drop", b.name)
		if b.name != "air" and drop != "" and not items.has(drop):
			push_warning("[Reg] block %s drops unknown item %s" % [b.name, drop])


func block(name: String) -> int:
	return block_ids.get(name, 0)


func block_def(id: int) -> Dictionary:
	return blocks[id] if id < blocks.size() else blocks[0]


func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_label(id: String) -> String:
	return items.get(id, {}).get("label", id)


func block_drop(id: int) -> String:
	var d := block_def(id)
	return d.get("drop", d.name)


func block_color(id: int) -> Color:
	var t := face_tiles[id * 6 + 2]
	return tile_avg[t] if t < tile_avg.size() else Color.GRAY


func icon(item_id: String) -> Texture2D:
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]
	var it := item(item_id)
	var img: Image
	if it.is_empty():
		img = TextureFactory.make_icon({"shape": "chunk", "c": ["#ff00ff", "#ff66ff", "#ffffff"]}, 1)
	elif it.type == "block":
		var bid: int = it.block
		if kind[bid] == Kind.PLANT:
			img = tile_images[face_tiles[bid * 6]].duplicate()
		else:
			img = TextureFactory.make_cube_icon(tile_images[face_tiles[bid * 6 + 2]], tile_images[face_tiles[bid * 6 + 4]], tile_images[face_tiles[bid * 6]])
	else:
		img = TextureFactory.make_icon(it.icon, hash(item_id))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[item_id] = tex
	return tex

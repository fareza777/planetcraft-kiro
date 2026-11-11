extends Node
## Game: settings, save/load and cross-system notifications. All saves are local files.

signal crafted(item: String, n: int)

const SAVE_DIR := "user://saves/slot0/"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 1

var settings := {"render_distance": 6, "sensitivity": 1.0, "show_fps": true, "glow": true, "touch": true, "render_scale": 1.0, "clouds": true, "button_scale": 1.0, "invert_y": false, "master_volume": 0.85, "ambience": 0.7, "fov": 72, "auto_jump": true, "camera_shake": true, "damage_numbers": true, "haptics": true}
var _defaults := {}
var world_seed := 0
var planet_id := "verdania"
var continue_requested := false
var meta: Dictionary = {}


func _ready() -> void:
	_defaults = settings.duplicate()
	load_settings()
	load_profile()
	if not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available():
		settings.touch = false
	apply_render_scale()
	apply_audio()


func apply_audio() -> void:
	var v := clampf(float(settings.master_volume), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.001)


func apply_render_scale() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = clampf(float(settings.render_scale), 0.4, 1.0)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		if OS.has_feature("mobile"):
			settings.render_distance = 5
			settings.glow = false
			settings.render_scale = 0.6
		return
	for k in settings:
		settings[k] = cf.get_value("settings", k, settings[k])


func reset_settings() -> void:
	var touch: bool = settings.touch
	settings = _defaults.duplicate()
	settings.touch = touch
	if OS.has_feature("mobile"):
		settings.render_distance = 5
		settings.glow = false
		settings.render_scale = 0.6
	save_settings()
	apply_render_scale()
	apply_audio()


func delete_save() -> void:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		for f in DirAccess.get_files_at(SAVE_DIR):
			DirAccess.remove_absolute(SAVE_DIR + f)
	meta = {}


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_DIR + "meta.dat")


# ---------------------------------------------------------------- profile (account-wide)
## Stellar Shards and store unlocks persist across expeditions (user://profile.dat).

const PROFILE_PATH := "user://profile.dat"
signal shards_changed(total: int)
var profile := {"shards": 0, "lifetime": 0, "owned": {}, "equipped": {}}


func load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	var d = f.get_var(false) if f != null else null
	if d is Dictionary:
		for k in d:
			profile[k] = d[k]


func save_profile() -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var(profile, false)


func add_shards(n: int) -> void:
	profile.shards = int(profile.shards) + n
	profile.lifetime = int(profile.lifetime) + maxi(n, 0)
	save_profile()
	shards_changed.emit(int(profile.shards))


func owns(id: String) -> bool:
	return int(Reg.store.get(id, {}).get("price", 1)) == 0 or profile.owned.has(id)


func buy(id: String) -> bool:
	var it: Dictionary = Reg.store.get(id, {})
	if it.is_empty() or owns(id) or int(profile.shards) < int(it.price):
		return false
	profile.shards = int(profile.shards) - int(it.price)
	profile.owned[id] = true
	if it.cat != "kit":
		profile.equipped[it.cat] = id
	save_profile()
	shards_changed.emit(int(profile.shards))
	return true


func equip(id: String) -> void:
	var it: Dictionary = Reg.store.get(id, {})
	if it.is_empty() or not owns(id):
		return
	profile.equipped[it.cat] = id
	save_profile()


func equipped(cat: String) -> String:
	return String(profile.equipped.get(cat, cat + "_default"))


func equipped_def(cat: String) -> Dictionary:
	return Reg.store.get(equipped(cat), Reg.store.get(cat + "_default", {}))


## Colours of the equipped cosmetic for a category (suit / laser / rover / ship).
func cosmetic(cat: String) -> Array:
	var it: Dictionary = Reg.store.get(equipped(cat), Reg.store.get(cat + "_default", {}))
	var out := []
	for c in it.get("colors", ["#ffffff"]):
		out.append(Color.html(c))
	return out


func owned_kits() -> Array:
	var out := []
	for id in profile.owned:
		if Reg.store.get(id, {}).get("cat", "") == "kit":
			out.append(Reg.store[id])
	return out


func start_new(seed_value: int) -> void:
	world_seed = seed_value
	planet_id = "verdania"
	meta = {}
	continue_requested = false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	for f in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR + f)


func load_meta() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_DIR + "meta.dat", FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var(false)
	if not (d is Dictionary) or int(d.get("version", 0)) != SAVE_VERSION:
		push_warning("[Game] incompatible save")
		return false
	meta = d
	world_seed = int(d.seed)
	planet_id = String(d.planet)
	continue_requested = true
	return true


func write_meta(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	d["version"] = SAVE_VERSION
	d["seed"] = world_seed
	d["planet"] = planet_id
	d["saved_at"] = Time.get_unix_time_from_system()
	meta = d
	var tmp := SAVE_DIR + "meta.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[Game] cannot write save")
		return
	f.store_var(d, false)
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_DIR + "meta.dat")


func save_mods(pid: String, mods: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var tmp := SAVE_DIR + pid + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return
	f.store_var(mods, false)
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_DIR + pid + ".mods")


func load_mods(pid: String) -> Dictionary:
	var path := SAVE_DIR + pid + ".mods"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var d = f.get_var(false)
	return d if d is Dictionary else {}


func save_state(pid: String, st: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var tmp := SAVE_DIR + pid + ".state.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(st, false)
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_DIR + pid + ".state")


func load_state(pid: String) -> Dictionary:
	var path := SAVE_DIR + pid + ".state"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var(false)
	return d if d is Dictionary else {}


func notify_crafted(item: String, n: int) -> void:
	crafted.emit(item, n)


## Logic checks used by tests/test_runner.gd.
func run_self_tests() -> Array:
	var out := []
	var inv := Inventory.new()
	out.append([inv.add("basalt", 100) == 0 and inv.count("basalt") == 100, "inventory stacks 100 basalt into 64+36"])
	out.append([inv.slots[0].n == 64 and inv.slots[1].n == 36, "stack limit respected"])
	out.append([inv.add("multitool_1", 2) == 0 and inv.slots[2].n == 1 and inv.slots[3].n == 1, "tools do not stack"])
	out.append([inv.remove("basalt", 70) and inv.count("basalt") == 30, "remove across stacks"])
	inv.remove("basalt", 25)
	inv.add("ferrite_chunk", 4)
	var fab: Dictionary = {}
	for r in Reg.recipes:
		if r.out == "fabricator":
			fab = r
	out.append([not fab.is_empty() and not inv.can_craft(fab), "cannot craft fabricator with 5 of 8 basalt"])
	inv.add("basalt", 3)
	out.append([inv.craft(fab) and inv.count("fabricator") == 1 and inv.count("ferrite_chunk") == 0 and inv.count("basalt") == 0, "craft fabricator consumes inputs"])
	var data := inv.to_data()
	var inv2 := Inventory.new()
	inv2.from_data(data)
	out.append([inv2.count("basalt") == inv.count("basalt") and inv2.count("fabricator") == 1, "inventory round-trips through save data"])
	var sv := Survival.new()
	sv.o2 = 1.0
	for i in 20:
		sv.update(0.5, {"temp": 20.0})
	out.append([sv.o2 == 0.0 and sv.hp < 100.0, "no oxygen causes damage"])
	var hp_before := sv.hp
	sv.update(1.0, {"temp": 20.0, "o2_zone": true})
	out.append([sv.o2 > 0.0, "oxygen zone refills oxygen"])
	out.append([sv.consume(Reg.item("medkit")) and sv.hp > hp_before, "medkit heals"])
	return out

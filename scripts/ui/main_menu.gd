class_name MainMenu
extends Node3D
## Title screen: a live voxel planet orbits behind the menu.

signal start_game(new_game: bool)

const TF := preload("res://scripts/ui/theme_factory.gd")

var world: VoxelWorld
var sky: SkyController
var cam: Camera3D
var _angle := 0.0
var _seed_edit: LineEdit
var _center := Vector3(8, 60, 8)


func _ready() -> void:
	var p: Dictionary = Reg.planets["verdania"]
	world = VoxelWorld.new()
	world.radius = 4 if OS.has_feature("mobile") else 5
	add_child(world)
	world.setup(p, 20261031, {})
	world.focus = _center
	sky = SkyController.new()
	add_child(sky)
	sky.setup(p, world.materials(), Game.settings.glow)
	sky.set_view_distance(world.radius * 16.0)
	sky.time_of_day = 0.74
	sky.day_length = 240.0
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 200
	add_child(cam)
	_center.y = float(world.gen.surface_height(8, 8)) + 6.0
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = ThemeFactory.build()
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.06, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(70, 60)
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var t1 := TF.label("PLANETCRAFT", 76, TF.CYAN)
	t1.add_theme_constant_override("shadow_offset_x", 4)
	t1.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(t1)
	v.add_child(TF.label("G A L A C T I C   S U R V I V A L", 24, TF.AMBER))
	var sp := Control.new()
	sp.custom_minimum_size.y = 24
	v.add_child(sp)
	if Game.has_save():
		v.add_child(TF.button("Continue Expedition", _on_continue, 420))
	var seed_row := HBoxContainer.new()
	v.add_child(seed_row)
	seed_row.add_child(TF.label("Seed", 20, TF.DIM))
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(randi() % 1000000)
	_seed_edit.custom_minimum_size = Vector2(200, 50)
	_seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_row.add_child(_seed_edit)
	v.add_child(TF.button("New Expedition", _on_new, 420))
	v.add_child(TF.button("Quit", func() -> void: get_tree().quit(), 420))
	var foot := TF.label("Offline voxel sandbox · v%s · Made with Godot and Kiro" % ProjectSettings.get_setting("application/config/version"), 16, TF.DIM)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(70, -50)
	root.add_child(foot)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_top = -44
	if Game.has_save() and Game.meta.is_empty():
		Game.load_meta()
		Game.continue_requested = false


func _on_continue() -> void:
	if Game.load_meta():
		_go(false)


func _on_new() -> void:
	var s := int(_seed_edit.text) if _seed_edit.text.is_valid_int() else hash(_seed_edit.text)
	Game.start_new(s)
	_go(true)


func _go(new_game: bool) -> void:
	world.shutdown()
	start_game.emit(new_game)


func _process(dt: float) -> void:
	_angle += dt * 0.06
	var p := _center + Vector3(cos(_angle) * 34.0, 14.0, sin(_angle) * 34.0)
	cam.global_position = p
	cam.look_at(_center + Vector3(0, -4, 0), Vector3.UP)
	world.focus = _center
	for m in world.materials():
		m.set_shader_parameter("lamp_range", 0.01)

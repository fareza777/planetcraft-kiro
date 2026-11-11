class_name Intro
extends CanvasLayer
## Animated studio splash shown after the boot splash: icon pop, light sweep, title reveal,
## "F7 DEVELOPER presents". Tap anywhere to skip. Emits `finished`.

signal finished

const TF := preload("res://scripts/ui/theme_factory.gd")

var _root: Control
var _icon: TextureRect
var _title: Label
var _studio: Label
var _sweep: ColorRect
var _done := false


func _ready() -> void:
	layer = 50
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(v)
	_studio = TF.label("F 7   D E V E L O P E R   P R E S E N T S", 18, TF.DIM)
	_studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_studio)
	_icon = TextureRect.new()
	_icon.texture = load("res://art/generated/icon_512.png")
	_icon.custom_minimum_size = Vector2(240, 240)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_icon)
	_title = TF.label("PLANETCRAFT", 64, TF.CYAN)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_sweep = ColorRect.new()
	_sweep.color = Color(1, 1, 1, 0.12)
	_sweep.size = Vector2(60, 2000)
	_sweep.rotation = 0.35
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sweep)
	_studio.modulate.a = 0.0
	_icon.modulate.a = 0.0
	_title.modulate.a = 0.0
	await get_tree().process_frame
	_icon.pivot_offset = _icon.size * 0.5
	_icon.scale = Vector2.ONE * 0.4
	var tw := create_tween()
	tw.tween_property(_studio, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(_icon, "modulate:a", 1.0, 0.35).set_delay(0.15)
	tw.parallel().tween_property(_icon, "scale", Vector2.ONE, 0.6).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_icon, "rotation", 0.0, 0.6).from(-0.3).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(_sweep, "position:x", _root.size.x + 200.0, 0.7).from(-300.0)
	tw.tween_interval(0.9)
	tw.tween_property(_root, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_finish)


func _on_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()

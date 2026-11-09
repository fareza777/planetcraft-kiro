class_name PauseMenu
extends Control
## Pause menu with settings. Emits actions for the world root to handle.

signal action(name: String)

const TF := preload("res://scripts/ui/theme_factory.gd")

var _rd_lbl: Label
var _sens_lbl: Label
var _fps_btn: Button
var _glow_btn: Button
var _rs_lbl: Label
var _cloud_btn: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(TF.label("EXPEDITION PAUSED", 30, TF.CYAN))
	v.add_child(TF.button("Resume", func() -> void: action.emit("resume"), 420))
	v.add_child(TF.button("Save Now", func() -> void: action.emit("save"), 420))
	var rd := HBoxContainer.new()
	v.add_child(rd)
	rd.add_child(TF.button("−", _rd.bind(-1), 64))
	_rd_lbl = TF.label("", 20)
	_rd_lbl.custom_minimum_size.x = 270
	_rd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rd.add_child(_rd_lbl)
	rd.add_child(TF.button("+", _rd.bind(1), 64))
	var se := HBoxContainer.new()
	v.add_child(se)
	se.add_child(TF.button("−", _sens.bind(-0.1), 64))
	_sens_lbl = TF.label("", 20)
	_sens_lbl.custom_minimum_size.x = 270
	_sens_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	se.add_child(_sens_lbl)
	se.add_child(TF.button("+", _sens.bind(0.1), 64))
	var toggles := HBoxContainer.new()
	v.add_child(toggles)
	_fps_btn = TF.button("", _toggle.bind("show_fps"), 206)
	_glow_btn = TF.button("", _toggle.bind("glow"), 206)
	toggles.add_child(_fps_btn)
	toggles.add_child(_glow_btn)
	var rs := HBoxContainer.new()
	v.add_child(rs)
	rs.add_child(TF.button("−", _rs.bind(-0.1), 64))
	_rs_lbl = TF.label("", 20)
	_rs_lbl.custom_minimum_size.x = 270
	_rs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rs.add_child(_rs_lbl)
	rs.add_child(TF.button("+", _rs.bind(0.1), 64))
	_cloud_btn = TF.button("", _toggle.bind("clouds"), 420)
	v.add_child(_cloud_btn)
	v.add_child(TF.button("Save & Quit to Title", func() -> void: action.emit("quit"), 420))
	_status = TF.label("", 16, TF.DIM)
	v.add_child(_status)
	_sync()


func set_status(t: String) -> void:
	_status.text = t


func _sync() -> void:
	_rd_lbl.text = "Render distance: %d chunks" % int(Game.settings.render_distance)
	_sens_lbl.text = "Look sensitivity: %.1f" % float(Game.settings.sensitivity)
	_fps_btn.text = "FPS: %s" % ("on" if Game.settings.show_fps else "off")
	_glow_btn.text = "Glow: %s" % ("on" if Game.settings.glow else "off")
	_rs_lbl.text = "Resolution: %d%%" % int(round(float(Game.settings.render_scale) * 100))
	_cloud_btn.text = "Clouds: %s" % ("on" if Game.settings.clouds else "off")


func _rd(d: int) -> void:
	Game.settings.render_distance = clampi(int(Game.settings.render_distance) + d, 3, 10)
	Game.save_settings()
	_sync()
	action.emit("settings")


func _sens(d: float) -> void:
	Game.settings.sensitivity = clampf(snappedf(float(Game.settings.sensitivity) + d, 0.1), 0.3, 3.0)
	Game.save_settings()
	_sync()
	action.emit("settings")


func _rs(d: float) -> void:
	Game.settings.render_scale = clampf(snappedf(float(Game.settings.render_scale) + d, 0.1), 0.4, 1.0)
	Game.save_settings()
	_sync()
	action.emit("settings")


func _toggle(k: String) -> void:
	Game.settings[k] = not Game.settings[k]
	Game.save_settings()
	_sync()
	action.emit("settings")

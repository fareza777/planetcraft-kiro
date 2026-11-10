class_name PauseMenu
extends Control
## Pause screen: big action buttons on the left, live settings and planet status on the right.

signal action(name: String)

const TF := preload("res://scripts/ui/theme_factory.gd")

var _status: Label
var _panel: PanelContainer
var _left: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", TF.box(Color(0.03, 0.03, 0.08, 0.96), TF.LINE, 18, 2, 22))
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	_panel.add_child(h)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 12)
	_left.custom_minimum_size.x = 330
	h.add_child(_left)
	_left.add_child(TF.label("PAUSED", 40, TF.CYAN))
	_status = TF.label("", 16, TF.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 320
	_left.add_child(_status)
	for b in [["▶  Resume", "resume", TF.GREEN], ["💾  Save now", "save", TF.CYAN], ["⏏  Save & quit to title", "quit", TF.AMBER]]:
		var btn := TF.button(b[0], func() -> void: action.emit(b[1]), 320)
		btn.custom_minimum_size.y = 64
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_stylebox_override("normal", TF.box(Color(0.08, 0.1, 0.2, 0.95), Color(b[2].r, b[2].g, b[2].b, 0.6), 14, 2, 18))
		btn.add_theme_stylebox_override("hover", TF.box(Color(0.12, 0.16, 0.3, 0.95), b[2], 14, 2, 18))
		_left.add_child(btn)
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	var sp := SettingsPanel.new()
	sp.changed.connect(func() -> void: action.emit("settings"))
	scroll.add_child(sp)
	resized.connect(_layout)
	visibility_changed.connect(_on_vis)


func _layout() -> void:
	var m := Vector2(clampf(size.x * 0.05, 20, 90), clampf(size.y * 0.06, 16, 50))
	_panel.position = m
	_panel.size = size - m * 2.0


func _on_vis() -> void:
	if visible:
		_layout()
		UiAnim.pop_in(_panel, 0.0, 0.94)
		var i := 0
		for c in _left.get_children():
			if c is Button:
				c.modulate.a = 0.0
				c.create_tween().tween_property(c, "modulate:a", 1.0, 0.25).set_delay(0.05 + i * 0.05)
				i += 1


func set_status(t: String) -> void:
	_status.text = t

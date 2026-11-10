class_name TouchScroll
extends Node
## Makes a ScrollContainer drag-scrollable on touch screens even when the drag starts on a
## button or slider: interactive descendants are switched to MOUSE_FILTER_PASS so the press
## also reaches the ScrollContainer. Text fields keep STOP so the keyboard still works.

var _t := 0.0


static func attach(scroll: ScrollContainer) -> void:
	scroll.scroll_deadzone = 12
	var ts := TouchScroll.new()
	scroll.add_child(ts, false, Node.INTERNAL_MODE_FRONT)


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.4
	var p := get_parent()
	if p is Control and (p as Control).is_visible_in_tree():
		_pass(p)


func _pass(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			var ctl := c as Control
			if not (ctl is LineEdit) and not (ctl is ScrollBar) and ctl.mouse_filter == Control.MOUSE_FILTER_STOP:
				ctl.mouse_filter = Control.MOUSE_FILTER_PASS
		_pass(c)

class_name Intro
extends CanvasLayer
## Splash chain: the PlanetCraft cinematic title (English voice-over), then the F7 Developer
## ident. Tap or any key skips the current clip. Emits `finished` when the chain is over.

signal finished

const TF := preload("res://scripts/ui/theme_factory.gd")
const BG := Color(0.027, 0.024, 0.047, 1.0)  # #07060C, matches the F7 ident end frame
const CLIPS := [
	"res://art/intro/intro.ogv",
	"res://art/intro/f7_brand.ogv",
]
const LOCKOUT := 0.7

var _root: Control
var _player: VideoStreamPlayer
var _fade: ColorRect
var _hint: Label
var _streams: Array = []
var _index := -1
var _done := false
var _started := 0
var _safety: Timer


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(aspect)
	_player = VideoStreamPlayer.new()
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.loop = false
	_player.autoplay = false
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_next_clip)
	aspect.add_child(_player)
	_hint = TF.label("TAP TO SKIP", 17, Color(1, 1, 1, 0.75))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-190, -48)
	_hint.modulate.a = 0.0
	_root.add_child(_hint)
	_safety = Timer.new()
	_safety.one_shot = true
	_safety.timeout.connect(_next_clip)
	add_child(_safety)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	for path in CLIPS:
		var s := load(path)
		if s is VideoStream:
			_streams.append(s)
	if _streams.is_empty():
		_done = true
		finished.emit.call_deferred()
		return
	_started = Time.get_ticks_msec() / 1000.0
	_play(0)
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	var hw := _hint.create_tween()
	hw.tween_interval(1.6)
	hw.tween_property(_hint, "modulate:a", 1.0, 0.4)


func _play(i: int) -> void:
	_index = i
	_player.stream = _streams[i]
	_player.play()
	_safety.start(30.0 if i == 0 else 8.0)


func current_clip() -> int:
	return _index


func skip_current() -> void:
	if _done:
		return
	_player.stop()
	_next_clip()


func skip_all() -> void:
	if _done:
		return
	_player.stop()
	_end()


func _next_clip() -> void:
	if _done:
		return
	if _index + 1 < _streams.size():
		_play(_index + 1)
		var hw := _hint.create_tween()
		hw.tween_property(_hint, "modulate:a", 0.0, 0.3)
		hw.tween_interval(0.8)
		hw.tween_property(_hint, "modulate:a", 0.9, 0.3)
	else:
		_end()


func _end() -> void:
	if _done:
		return
	_done = true
	_safety.stop()
	_hint.visible = false
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _input(e: InputEvent) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _started < LOCKOUT:
		return
	var tapped: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	var keyed: bool = e is InputEventKey and e.pressed and not e.echo
	if tapped or keyed:
		get_viewport().set_input_as_handled()
		skip_current()

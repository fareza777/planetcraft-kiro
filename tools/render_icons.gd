extends SceneTree
## Renders the app icon SVG into the PNG files Android needs.
## Run: godot --headless --path . -s tools/render_icons.gd

func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://art/icon_full.svg")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/generated"))
	# full icon (legacy launcher, store listing 512, splash logo)
	for sz in [192, 512, 1024]:
		var img := Image.new()
		img.load_svg_from_string(svg, sz / 1024.0)
		img.save_png("res://art/generated/icon_%d.png" % sz)
	# adaptive icon: background = full art; foreground = art scaled into the 66% safe zone
	var bg := Image.new()
	bg.load_svg_from_string(svg, 432.0 / 1024.0)
	bg.save_png("res://art/generated/icon_background_432.png")
	var fg_svg := svg.replace("<rect width=\"1024\" height=\"1024\" fill=\"url(#bg)\"/>", "")
	var fg_full := Image.new()
	fg_full.load_svg_from_string(fg_svg, 300.0 / 1024.0)
	var fg := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	fg.blit_rect(fg_full, Rect2i(0, 0, 300, 300), Vector2i(66, 66))
	fg.save_png("res://art/generated/icon_foreground_432.png")
	var mono: Image = fg.duplicate()
	for y in 432:
		for x in 432:
			var c := mono.get_pixel(x, y)
			mono.set_pixel(x, y, Color(1, 1, 1, c.a))
	mono.save_png("res://art/generated/icon_monochrome_432.png")
	# boot splash: logo centred on the game's background colour
	var splash := Image.create_empty(1280, 720, false, Image.FORMAT_RGBA8)
	splash.fill(Color(0.03, 0.02, 0.07, 1.0))
	var logo := Image.new()
	logo.load_svg_from_string(svg, 420.0 / 1024.0)
	logo.convert(Image.FORMAT_RGBA8)
	var rounded := _round(logo, 90)
	splash.blend_rect(rounded, Rect2i(0, 0, 420, 420), Vector2i(430, 110))
	splash.save_png("res://art/generated/splash.png")
	print("icons rendered")
	quit()


func _round(img: Image, r: int) -> Image:
	var out: Image = img.duplicate()
	var w := out.get_width()
	var h := out.get_height()
	for y in h:
		for x in w:
			var dx := maxi(maxi(r - x, x - (w - 1 - r)), 0)
			var dy := maxi(maxi(r - y, y - (h - 1 - r)), 0)
			if dx * dx + dy * dy > r * r:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out

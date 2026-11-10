extends Node
## Entry point: switches between the title screen and planet sessions (including jumps
## between planets). User args after `--`: `autotest` runs the scripted gameplay bot,
## `planet=<id>` starts the bot on a specific planet.

var menu: MainMenu
var session: WorldRoot
var music: Music


func _ready() -> void:
	music = Music.new()
	add_child(music)
	var args := OS.get_cmdline_user_args()
	if args.has("creaturetest"):
		Game.start_new(4242)
		_start("new")
		var cs = load("res://tests/creature_showcase.gd").new()
		cs.root = session
		session.bot_driven = true
		add_child(cs)
		return
	if args.has("menutest"):
		show_menu()
		_menu_shots()
		return
	if args.has("autotest"):
		Game.start_new(4242)
		for a in args:
			if a.begins_with("planet="):
				Game.planet_id = a.substr(7)
		_start("new")
		var bot = load("res://tests/autoplay.gd").new()
		bot.root = session
		session.bot_driven = true
		add_child(bot)
		return
	show_menu()


func show_menu() -> void:
	_end_session()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = MainMenu.new()
	add_child(menu)
	menu.start_game.connect(_on_start)


func _end_session() -> void:
	if session != null:
		session.world.shutdown()
		session.queue_free()
		session = null


func _on_start(new_game: bool) -> void:
	menu.queue_free()
	menu = null
	_start("new" if new_game else "continue")


func _start(mode: String) -> void:
	session = WorldRoot.new()
	add_child(session)
	session.start(Game.planet_id, mode)
	session.exit_to_title.connect(show_menu)
	session.travel_to.connect(_on_travel)


func _on_travel(_pid: String) -> void:
	_end_session()
	Game.load_meta()
	_start("arrive")


func _menu_shots() -> void:
	var dir := "user://" if OS.has_feature("mobile") else "res://test_output/"
	await get_tree().create_timer(4.0).timeout
	get_viewport().get_texture().get_image().save_png(dir + "menu_01_title.png")
	menu._show_settings()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir + "menu_02_settings.png")
	menu._hide_overlay()
	menu._show_new()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir + "menu_03_new.png")
	menu._hide_overlay()
	Game.profile.shards = int(Game.profile.shards) + 0
	menu._show_store()
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(dir + "menu_04_store.png")
	print("[MENUTEST] done")
	get_tree().quit()


func _process(_dt: float) -> void:
	if music == null:
		return
	if session != null and is_instance_valid(session) and session.sky != null:
		music.daylight = session.sky.daylight
	else:
		music.daylight = 0.8

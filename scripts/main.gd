extends Node
## Entry point: switches between the title screen and a planet session.
## Command-line user args (after `--`): `autotest` runs the scripted gameplay bot.

var menu: MainMenu
var session: WorldRoot


func _ready() -> void:
	if OS.get_cmdline_user_args().has("autotest"):
		Game.start_new(4242)
		_start(true)
		var bot = load("res://tests/autoplay.gd").new()
		bot.root = session
		session.bot_driven = true
		add_child(bot)
		return
	show_menu()


func show_menu() -> void:
	if session != null:
		session.world.shutdown()
		session.queue_free()
		session = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = MainMenu.new()
	add_child(menu)
	menu.start_game.connect(_on_start)


func _on_start(new_game: bool) -> void:
	menu.queue_free()
	menu = null
	_start(new_game)


func _start(new_game: bool) -> void:
	session = WorldRoot.new()
	add_child(session)
	session.start(Game.planet_id, new_game)
	session.exit_to_title.connect(show_menu)

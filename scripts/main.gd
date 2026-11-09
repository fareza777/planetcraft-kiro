extends Node
## Entry point: switches between the title screen and planet sessions (including jumps
## between planets). User args after `--`: `autotest` runs the scripted gameplay bot,
## `planet=<id>` starts the bot on a specific planet.

var menu: MainMenu
var session: WorldRoot


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
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

class_name Platform
extends RefCounted
## Android integrations through Godot 4.4+ JavaClassWrapper + the built-in AndroidRuntime
## plugin (no Gradle build or third-party plugin needed). Desktop falls back to the browser /
## clipboard.

const PACKAGE := "com.f7developer.planetcraft"
const REPO_URL := "https://github.com/fareza777/planetcraft-kiro"
const STORE_URL := "https://play.google.com/store/apps/details?id=" + PACKAGE


static func _runtime() -> Object:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return null
	return Engine.get_singleton("AndroidRuntime")


## Opens the Android share sheet. Returns false if sharing was not possible (then the text is
## copied to the clipboard instead).
static func share(text: String) -> bool:
	var rt := _runtime()
	if rt != null:
		var Intent = JavaClassWrapper.wrap("android.content.Intent")
		var activity = rt.getActivity()
		if Intent != null and activity != null:
			var send = Intent.Intent()
			send.setAction(Intent.ACTION_SEND)
			send.putExtra(Intent.EXTRA_TEXT, text)
			send.setType("text/plain")
			var chooser = Intent.createChooser(send, "Share PlanetCraft")
			activity.startActivity(chooser)
			return true
	DisplayServer.clipboard_set(text)
	return false


## Opens the Play Store page (market:// first, then the web URL).
static func rate() -> void:
	if OS.get_name() == "Android":
		if OS.shell_open("market://details?id=" + PACKAGE) == OK:
			return
	OS.shell_open(STORE_URL)


static func open_url(url: String) -> void:
	OS.shell_open(url)


## Short haptic pulse (respects the Haptics setting).
static func vibrate(ms: int) -> void:
	if not Game.settings.get("haptics", true):
		return
	if OS.get_name() == "Android":
		Input.vibrate_handheld(ms)

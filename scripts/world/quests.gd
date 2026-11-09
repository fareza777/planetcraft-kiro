class_name Quests
extends RefCounted
## Data-driven quest chain (data/quests.json). Progress is event-driven; "collect" goals are
## checked against the inventory. State is saved in the player meta.

signal completed(q: Dictionary)

var index := 0
var progress := 0
var visited := {}
var inv: Inventory


func current() -> Dictionary:
	return Reg.quests[index] if index < Reg.quests.size() else {}


func tracker_text() -> String:
	var q := current()
	if q.is_empty():
		return "All directives complete. Keep terraforming the stars."
	var g: Dictionary = q.goal
	var n := int(g.n)
	var have := progress
	if g.type == "collect" and inv != null:
		have = inv.count(g.id)
	var count_txt := (" (%d/%d)" % [mini(have, n), n]) if n > 1 else ""
	return "◆ %s — %s%s" % [q.title, q.text, count_txt]


func event(kind: String, id: String, amount := 1) -> void:
	var q := current()
	if q.is_empty():
		return
	var g: Dictionary = q.goal
	var t: String = g.type
	if t == kind and (g.id == "" or g.id == id):
		progress += amount
	elif t == "visit_any" and kind == "visit" and id != "verdania":
		progress += 1
	_check()


func check_collect() -> void:
	_check()


func _check() -> void:
	var q := current()
	if q.is_empty():
		return
	var g: Dictionary = q.goal
	var done := false
	if g.type == "collect":
		done = inv != null and inv.count(g.id) >= int(g.n)
	else:
		done = progress >= int(g.n)
	if done:
		index += 1
		progress = 0
		completed.emit(q)
		# visits that already happened count for later visit goals
		var nq := current()
		if not nq.is_empty() and nq.goal.type == "visit" and visited.has(nq.goal.id):
			progress = 1
			_check()


func to_data() -> Dictionary:
	return {"index": index, "progress": progress, "visited": visited}


func from_data(d: Dictionary) -> void:
	index = int(d.get("index", 0))
	progress = int(d.get("progress", 0))
	visited = d.get("visited", {})

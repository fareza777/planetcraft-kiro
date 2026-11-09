class_name Quests
extends RefCounted
## Main story (data/quests.json, chapters) and NPC side jobs (data/side_quests.json).
## Progress is event-driven. "collect" goals read the inventory; "deliver" goals are turned
## in at the giver. State is saved in the player meta.

signal completed(q: Dictionary)
signal started(q: Dictionary)
signal side_ready(q: Dictionary)
signal side_done(q: Dictionary)

const CHAPTERS := ["", "I · Crash Site", "II · Haven", "III · Foothold", "IV · Beyond the Sky", "V · The Anomaly", "VI · Gaia"]

var index := 0
var progress := 0
var visited := {}
var inv: Inventory
var side := {}          # id -> {"progress": int}
var side_done_count := {}
var bestiary := {}      # creature id -> {"kills": int, "drops": {item: true}}


func record_kill(id: String) -> void:
	var base := id
	if not bestiary.has(base):
		bestiary[base] = {"kills": 0, "drops": {}}
	bestiary[base].kills = int(bestiary[base].kills) + 1


func record_drop(src: String, item: String) -> void:
	if not Reg.creatures.has(src):
		return
	if not bestiary.has(src):
		bestiary[src] = {"kills": 0, "drops": {}}
	bestiary[src].drops[item] = true


func current() -> Dictionary:
	return Reg.quests[index] if index < Reg.quests.size() else {}


func chapter_name(q: Dictionary) -> String:
	return CHAPTERS[clampi(int(q.get("chapter", 1)), 0, CHAPTERS.size() - 1)]


func goal_progress(q: Dictionary, prog: int) -> Vector2i:
	var g: Dictionary = q.goal
	match g.type:
		"collect", "deliver":
			return Vector2i(mini(inv.count(g.id) if inv else 0, int(g.n)), int(g.n))
		"deliver_multi":
			var have := 0
			var need := 0
			for k in g.items:
				need += int(g.items[k])
				have += mini(inv.count(k) if inv else 0, int(g.items[k]))
			return Vector2i(have, need)
	return Vector2i(mini(prog, int(g.get("n", 1))), int(g.get("n", 1)))


func tracker_text() -> String:
	var q := current()
	if q.is_empty():
		return "All directives complete. Keep terraforming the stars."
	var gp := goal_progress(q, progress)
	var count_txt := (" (%d/%d)" % [gp.x, gp.y]) if gp.y > 1 else ""
	return "◆ %s — %s%s" % [q.title, q.text, count_txt]


func _matches(g: Dictionary, kind: String, id: String) -> bool:
	if g.type == "visit_any":
		return kind == "visit" and id != "verdania"
	return g.type == kind and (String(g.get("id", "")) == "" or g.id == id)


func event(kind: String, id: String, amount := 1) -> void:
	var q := current()
	if not q.is_empty() and _matches(q.goal, kind, id):
		progress += amount
	for sid in side:
		var sq: Dictionary = Reg.side_quests.get(sid, {})
		if sq.is_empty():
			continue
		var was := side_complete(sid)
		if _matches(sq.goal, kind, id):
			side[sid].progress = int(side[sid].progress) + amount
		if not was and side_complete(sid):
			side_ready.emit(sq)
	_check()


func check_collect() -> void:
	_check()


func _check() -> void:
	var q := current()
	if q.is_empty():
		return
	var gp := goal_progress(q, progress)
	if gp.x >= gp.y:
		index += 1
		progress = 0
		completed.emit(q)
		var nq := current()
		if not nq.is_empty():
			started.emit(nq)
			if nq.goal.type == "visit" and visited.has(nq.goal.id):
				progress = 1
				_check()


# ---------------------------------------------------------------- side jobs

func side_state(sid: String) -> String:
	if side.has(sid):
		return "ready" if side_complete(sid) else "active"
	var sq: Dictionary = Reg.side_quests.get(sid, {})
	if side_done_count.has(sid) and not sq.get("repeat", false):
		return "done"
	return "available"


func side_complete(sid: String) -> bool:
	if not side.has(sid):
		return false
	var sq: Dictionary = Reg.side_quests[sid]
	var gp := goal_progress(sq, int(side[sid].progress))
	return gp.x >= gp.y


func accept(sid: String) -> void:
	if not side.has(sid):
		side[sid] = {"progress": 0}


func abandon(sid: String) -> void:
	side.erase(sid)


func turn_in(sid: String) -> bool:
	if not side_complete(sid):
		return false
	var sq: Dictionary = Reg.side_quests[sid]
	var g: Dictionary = sq.goal
	if g.type == "deliver":
		inv.remove(g.id, int(g.n))
	elif g.type == "deliver_multi":
		for k in g.items:
			inv.remove(k, int(g.items[k]))
	side.erase(sid)
	side_done_count[sid] = int(side_done_count.get(sid, 0)) + 1
	side_done.emit(sq)
	return true


func ready_count() -> int:
	var n := 0
	for sid in side:
		if side_complete(sid):
			n += 1
	return n


func npc_marker(npc_id: String) -> String:
	var npc: Dictionary = Reg.npcs.get(npc_id, {})
	for sid in npc.get("jobs", []):
		if side_state(sid) == "ready":
			return "?"
	for sid in npc.get("jobs", []):
		if side_state(sid) == "available":
			return "!"
	return ""


func to_data() -> Dictionary:
	return {"index": index, "progress": progress, "visited": visited, "side": side, "side_done": side_done_count, "bestiary": bestiary}


func from_data(d: Dictionary) -> void:
	index = int(d.get("index", 0))
	progress = int(d.get("progress", 0))
	visited = d.get("visited", {})
	side = d.get("side", {})
	side_done_count = d.get("side_done", {})
	bestiary = d.get("bestiary", {})

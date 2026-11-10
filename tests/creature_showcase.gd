extends Node
## `godot --path . -- creaturetest`: spawns every creature in a line, screenshots them, then
## lasers one for 3 s and checks it does not get launched (knockback regression test).

var root: WorldRoot
var t := 0.0
var step := 0
var row: Array = []
var _start := Vector3.ZERO


func _process(dt: float) -> void:
	t += dt
	if root == null or root.loading.visible:
		return
	var p := root.player
	match step:
		0:
			if t > 2.0:
				p.yaw = 0.0
				p.pitch = -0.12
				var base := p.global_position + Vector3(-9, 0, -9)
				var i := 0
				for id in Reg.creatures:
					if id == "void_guardian":
						continue
					var pos := base + Vector3(i * 2.2, 0, -(i % 2) * 2.0)
					var top := root.world.column_top(floori(pos.x), floori(pos.z))
					pos.y = top + 1.0 + (2.0 if Reg.creatures[id].get("fly", false) else 0.0)
					var c := root.creatures.spawn(id, pos, false, i == 3)
					c.speed = 0.0
					c.def = c.def.duplicate()
					c.def["behavior"] = "passive"
					c.def["aggro"] = 0
					row.append(c)
					i += 1
				root.sky.time_of_day = 0.4
				step = 1
				t = 0.0
		1:
			for c in row:
				if is_instance_valid(c):
					c.vel.x = 0
					c.vel.z = 0
			if t > 2.5:
				get_viewport().get_texture().get_image().save_png("res://test_output/creatures.png")
				print("[CREATURES] screenshot test_output/creatures.png")
				var c: Creature = row[0]
				c.max_hp = 100000.0
				c.hp = 100000.0
				_start = c.global_position
				step = 2
				t = 0.0
		2:
			var c: Creature = row[0]
			var to := c.center() - p.eye_pos()
			p.yaw = atan2(-to.x, -to.z)
			p.pitch = atan2(to.y, Vector2(to.x, to.z).length())
			p.inv.slots[8] = {"id": "multitool_1", "n": 1}
			p.selected = 8
			p.ctl.mine = true
			if t > 3.0:
				p.ctl.mine = false
				var moved := Vector2(c.global_position.x - _start.x, c.global_position.z - _start.z).length()
				var ok := moved < 3.0 and c.global_position.y < _start.y + 2.0
				print("[CREATURES] %s laser knockback: moved %.2f m, rose %.2f m" % ["PASS" if ok else "FAIL", moved, c.global_position.y - _start.y])
				get_tree().quit(0 if ok else 1)

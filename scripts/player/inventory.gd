class_name Inventory
extends RefCounted
## Slot-based inventory: 9 hotbar slots + 27 backpack slots. A slot is null or {"id", "n"}.

signal changed

const SIZE := 36
const HOTBAR := 9

var slots: Array = []


func _init() -> void:
	slots.resize(SIZE)


static func stack_of(id: String) -> int:
	return int(Reg.item(id).get("stack", 64))


func add(id: String, n: int) -> int:
	if n <= 0 or not Reg.items.has(id):
		return n
	var max_stack := stack_of(id)
	for i in SIZE:
		var s = slots[i]
		if s != null and s.id == id and s.n < max_stack:
			var k := mini(n, max_stack - s.n)
			s.n += k
			n -= k
			if n == 0:
				break
	if n > 0:
		for i in SIZE:
			if slots[i] == null:
				var k := mini(n, max_stack)
				slots[i] = {"id": id, "n": k}
				n -= k
				if n == 0:
					break
	changed.emit()
	return n


func count(id: String) -> int:
	var c := 0
	for s in slots:
		if s != null and s.id == id:
			c += s.n
	return c


func remove(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	for i in range(SIZE - 1, -1, -1):
		var s = slots[i]
		if s != null and s.id == id:
			var k := mini(n, int(s.n))
			s.n -= k
			n -= k
			if s.n <= 0:
				slots[i] = null
			if n == 0:
				break
	changed.emit()
	return true


func remove_at(i: int, n: int = 1) -> void:
	var s = slots[i]
	if s == null:
		return
	s.n -= n
	if s.n <= 0:
		slots[i] = null
	changed.emit()


func has_all(req: Dictionary) -> bool:
	for k in req:
		if count(k) < int(req[k]):
			return false
	return true


func free_space_for(id: String) -> int:
	var max_stack := stack_of(id)
	var c := 0
	for s in slots:
		if s == null:
			c += max_stack
		elif s.id == id:
			c += max_stack - int(s.n)
	return c


func swap(a: int, b: int) -> void:
	var sa = slots[a]
	var sb = slots[b]
	if sa != null and sb != null and sa.id == sb.id and a != b:
		var max_stack := stack_of(sa.id)
		var k := mini(int(sa.n), max_stack - int(sb.n))
		sb.n += k
		sa.n -= k
		if sa.n <= 0:
			slots[a] = null
	else:
		slots[a] = sb
		slots[b] = sa
	changed.emit()


func to_data() -> Array:
	var out := []
	for s in slots:
		out.append(null if s == null else {"id": s.id, "n": s.n})
	return out


func from_data(data: Array) -> void:
	slots.clear()
	slots.resize(SIZE)
	for i in mini(data.size(), SIZE):
		var s = data[i]
		if s != null and Reg.items.has(s.id):
			slots[i] = {"id": String(s.id), "n": int(s.n)}
	changed.emit()


# ------------------------------------------------------------- crafting

static func recipes_for(stations: Array) -> Array:
	var out := []
	for r in Reg.recipes:
		var st: String = r.get("station", "hand")
		if st == "hand" or stations.has(st):
			out.append(r)
	return out


func can_craft(r: Dictionary) -> bool:
	return has_all(r.in) and free_space_for(r.out) >= int(r.get("n", 1))


func craft(r: Dictionary) -> bool:
	if not can_craft(r):
		return false
	for k in r.in:
		remove(k, int(r.in[k]))
	add(r.out, int(r.get("n", 1)))
	return true

extends RefCounted
class_name RoomGenerator

# Hotline-style floor plan: non-overlapping rectangular rooms stapled
# together with 2-wide L corridors. Returns tile-space data; the level
# paints it onto the TileMapLayer.

var rooms: Array[Rect2i] = []
var floors: Dictionary = {}
var corridors: Dictionary = {}
var rng := RandomNumberGenerator.new()

func generate(p_map_w: int = 84, p_map_h: int = 84, max_rooms: int = 10, min_size: int = 6, max_size: int = 13, level_seed: int = -1) -> Dictionary:
	rooms.clear()
	floors.clear()
	corridors.clear()
	if level_seed >= 0:
		rng.seed = level_seed
	else:
		rng.randomize()

	var attempts: int = 0
	while rooms.size() < max_rooms and attempts < max_rooms * 12:
		attempts += 1
		var w: int = rng.randi_range(min_size, max_size)
		var h: int = rng.randi_range(min_size, max_size)
		var x: int = rng.randi_range(2, p_map_w - w - 3)
		var y: int = rng.randi_range(2, p_map_h - h - 3)
		var candidate := Rect2i(x, y, w, h)
		if _overlaps_any(candidate):
			continue
		rooms.append(candidate)
		_carve_room(candidate)

	# Chain every room to the next so the whole floor is connected.
	for i in range(1, rooms.size()):
		_carve_corridor(_room_center(rooms[i - 1]), _room_center(rooms[i]))
	# A couple of extra loops so movement never dead-ends.
	for i in range(2):
		if rooms.size() > 3:
			var a: Vector2i = _room_center(rooms[rng.randi_range(0, rooms.size() - 1)])
			var b: Vector2i = _room_center(rooms[rng.randi_range(0, rooms.size() - 1)])
			if a != b:
				_carve_corridor(a, b)

	return {"floors": floors, "corridors": corridors, "rooms": rooms.duplicate(), "map_w": p_map_w, "map_h": p_map_h}

func _overlaps_any(candidate: Rect2i) -> bool:
	var padded := candidate.grow(1)
	for room in rooms:
		if padded.intersects(room):
			return true
	return false

func _carve_room(room: Rect2i) -> void:
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			floors[Vector2i(x, y)] = true

func _room_center(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x + room.size.x / 2.0, room.position.y + room.size.y / 2.0)

func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	# 3-wide tunnels: roomy enough for the player and enemies to pass.
	var cur := from
	while cur.x != to.x:
		cur.x += signi(to.x - cur.x)
		_carve_h(cur)
	while cur.y != to.y:
		cur.y += signi(to.y - cur.y)
		_carve_v(cur)

func _carve_h(cell: Vector2i) -> void:
	for dy in [-1, 0, 1]:
		_carve_floor(cell + Vector2i(0, dy), true)

func _carve_v(cell: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		_carve_floor(cell + Vector2i(dx, 0), true)

func _carve_floor(cell: Vector2i, is_corridor: bool = false) -> void:
	floors[cell] = true
	if is_corridor:
		corridors[cell] = true

func signi(v: int) -> int:
	return 1 if v > 0 else -1

extends Node2D
class_name GameLevel

const TILE: int = 16
const WALL_CELL := Vector2i(4, 0)
const GROUND_TEX: Texture2D = preload("res://assets/gfx/ground_bg/ground_texture.png")

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var bg_tile_map: TileMapLayer = $BGTileMapLayer
@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var upgrade_ui: UpgradeUI = $UpgradeUI
@onready var wave_manager: WaveManager = $WaveManager
@onready var ui_hud: CanvasLayer = $UIHUD
@onready var death_screen: CanvasLayer = $DeathScreen

const BOMB_TEX: Texture2D = preload("res://assets/gfx/cutscenes/outro/bomb.png")

var pickup_scene: PackedScene = load("res://src/level/pickup.tscn")
var outro_running: bool = false
var _outro_skip: bool = false
var _bg_ready: bool = false
var map_bounds_px := Rect2()
var kills_since_ammo: int = 0
var kills_since_heal: int = 0
var astar := AStar2D.new()
var astar_stride: int = 0
var path_ready: bool = false
# Furniture: solid room dressing on the grid; blocked cells stay out of
# the path grid and enemy spawns.
const FURN_TEX: Texture2D = preload("res://assets/gfx/furniture/furniture.png")
const FURN_CORNER := 13
const FURN_CABINETS: Array[int] = [14, 15, 16, 19, 20]
const FURN_TABLES: Array[int] = [17, 18]
const FURN_DOOR := 21
const DECO_WINDOW_TOP := 6
const DECO_WINDOW_BOTTOM := 7
const DECO_WIDE_LEFT := 8
const DECO_WIDE_RIGHT := 9
const PLAIN_WALL := Vector2i(5, 0)

var furniture_nodes: Array[Node] = []
var blocked_cells: Dictionary = {}

func _ready() -> void:
	add_to_group("level")

	if pause_menu != null:
		pause_menu.visible = false
	if upgrade_ui != null:
		upgrade_ui.visible = false
	if death_screen != null:
		death_screen.visible = false

	_setup_bg_tileset()

	var stats := PlayerStats.new()
	stats.current_health = stats.max_health
	player.stats = stats

	var katana := Katana.new()
	katana.slash_scene = load("res://src/weapon/slash.tscn") as PackedScene
	player.katana = katana

	var gun := Gun.new()
	gun.bullet_scene = load("res://src/weapon/bullet.tscn") as PackedScene
	player.gun = gun

	var enemy_scenes: Array[PackedScene] = [
		load("res://src/enemies/office_plankton.tscn") as PackedScene,
		load("res://src/enemies/security_officer.tscn") as PackedScene,
		load("res://src/enemies/boss.tscn") as PackedScene
	]
	wave_manager.add_to_group("wave_manager")
	wave_manager.start_waves(player, enemy_scenes)
	wave_manager.wave_ended.connect(_on_wave_ended)
	wave_manager.upgrade_phase_started.connect(_on_upgrade_phase)
	wave_manager.final_floor_cleared.connect(_on_final_floor_cleared)

	upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	if GameManager.consume_intro_flag():
		_start_after_intro()
	else:
		begin_wave()

func _start_after_intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.0)
	await tw.finished
	await get_tree().create_timer(0.6).timeout
	GameManager.play_battle_music()
	begin_wave()
	layer.queue_free()

func _setup_bg_tileset() -> void:
	var img: Image = GROUND_TEX.get_image()
	img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(Vector2i(0, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	bg_tile_map.tile_set = ts

func begin_wave() -> void:
	# Floor change sweeps every leftover: enemies, bullets, drops, bodies.
	get_tree().call_group("enemies", "queue_free")
	get_tree().call_group("bullets", "queue_free")
	get_tree().call_group("pickups", "queue_free")
	get_tree().call_group("corpses", "queue_free")
	# Fresh roguelike floor every wave; player keeps stats and loot.
	_build_floor(wave_manager.get_current_wave() + 1)
	wave_manager.set_arena(wave_manager.spawn_rooms, map_bounds_px, blocked_cells)
	wave_manager.safe_center = player.global_position
	wave_manager.call("_start_next_wave")

func _build_floor(wave_number: int) -> void:
	tile_map.clear()
	if not _bg_ready:
		bg_tile_map.clear()
	_clear_furniture()
	var gen := RoomGenerator.new()
	var result: Dictionary = gen.generate(84, 84, 10, 6, 13)
	var rooms: Array = result["rooms"]
	var floor_set: Dictionary = result["floors"]
	var corridor_set: Dictionary = result["corridors"]
	var map_w: int = result["map_w"]
	var map_h: int = result["map_h"]

	var floors: Array[Vector2i] = []
	var walls: Array[Vector2i] = []

	for cell in floor_set:
		# Record floors into an array
		floors.append(cell)

		# Walls anywhere an empty cell touches floor.
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n: Vector2i = cell + Vector2i(dx, dy)
				if not floor_set.has(n):
					walls.append(n)
					#tile_map.set_cell(n, 0, WALL_CELL)

	BetterTerrain.set_cells(tile_map, floors, 0)
	BetterTerrain.set_cells(tile_map, walls, 1)

	# Solid border around the whole map.
	#for x in range(-2, map_w + 2):
	#	tile_map.set_cell(Vector2i(x, -2), 0, WALL_CELL)
	#	tile_map.set_cell(Vector2i(x, -1), 0, WALL_CELL)
	#	tile_map.set_cell(Vector2i(x, map_h + 1), 0, WALL_CELL)
	#	tile_map.set_cell(Vector2i(x, map_h + 2), 0, WALL_CELL)
	#for y in range(-2, map_h + 2):
	#	tile_map.set_cell(Vector2i(-2, y), 0, WALL_CELL)
	#	tile_map.set_cell(Vector2i(-1, y), 0, WALL_CELL)
	#	tile_map.set_cell(Vector2i(map_w + 1, y), 0, WALL_CELL)
	#	tile_map.set_cell(Vector2i(map_w + 2, y), 0, WALL_CELL)

	BetterTerrain.update_terrain_area(tile_map, Rect2i(0, 0, map_w, map_h), false)

	# Fill background with ground texture (32px tile, so 2x2 cells per tile map cell).
	# Identical every floor: paint once per level instance instead of
	# ~8k set_cell calls on every transition.
	if not _bg_ready:
		_bg_ready = true
		for x in range(-2, map_w + 2):
			for y in range(-2, map_h + 2):
				bg_tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

	var reserved: Dictionary = _place_furniture_pass(floor_set, corridor_set, rooms, wave_number, map_w, map_h)
	_place_deco_pass(floor_set, map_w, map_h, reserved)
	_sanitize_deco(floor_set, map_w, map_h)
	_build_pathgrid(floor_set, map_w)

	var room_list: Array = []
	for room in rooms:
		room_list.append(room)
	wave_manager.spawn_rooms = room_list
	map_bounds_px = Rect2(Vector2(2, 2) * TILE, Vector2(map_w - 3, map_h - 3) * TILE)

	# Player starts in the first room, camera snaps to them.
	if not room_list.is_empty():
		var first: Rect2i = room_list[0]
		var start := Vector2((first.position.x + first.size.x * 0.5) * TILE, (first.position.y + first.size.y * 0.5) * TILE)
		player.global_position = start
		player.velocity = Vector2.ZERO
		camera.global_position = start
		camera.reset_smoothing()

func _cell_id(c: Vector2i) -> int:
	return c.y * astar_stride + c.x

func _build_pathgrid(floor_set: Dictionary, map_w: int) -> void:
	astar = AStar2D.new()
	astar_stride = maxi(map_w, 1)
	for cell in floor_set:
		var c: Vector2i = cell
		if blocked_cells.has(c):
			continue
		astar.add_point(_cell_id(c), Vector2(c))
	for cell in floor_set:
		var c: Vector2i = cell
		if blocked_cells.has(c):
			continue
		var e: Vector2i = c + Vector2i(1, 0)
		var s: Vector2i = c + Vector2i(0, 1)
		if floor_set.has(e) and not blocked_cells.has(e):
			astar.connect_points(_cell_id(c), _cell_id(e))
		if floor_set.has(s) and not blocked_cells.has(s):
			astar.connect_points(_cell_id(c), _cell_id(s))
	path_ready = true

func find_path(from_px: Vector2, to_px: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not path_ready or astar.get_point_count() == 0:
		return out
	var a: Vector2i = tile_map.local_to_map(tile_map.to_local(from_px))
	var b: Vector2i = tile_map.local_to_map(tile_map.to_local(to_px))
	var ida: int = astar.get_closest_point(Vector2(a))
	var idb: int = astar.get_closest_point(Vector2(b))
	if ida < 0 or idb < 0:
		return out
	for p in astar.get_point_path(ida, idb):
		out.append(tile_map.to_global(tile_map.map_to_local(p)))
	return out

func snap_to_floor(px: Vector2) -> Vector2:
	if not path_ready or astar.get_point_count() == 0:
		return px
	var c: Vector2i = tile_map.local_to_map(tile_map.to_local(px))
	var id: int = astar.get_closest_point(Vector2(c))
	if id < 0 or not astar.has_point(id):
		return px
	return tile_map.to_global(tile_map.map_to_local(Vector2i(astar.get_point_position(id))))

func _clear_furniture() -> void:
	for n in furniture_nodes:
		if is_instance_valid(n):
			n.queue_free()
	furniture_nodes.clear()
	blocked_cells.clear()

func _room_at(c: Vector2i, rooms: Array) -> bool:
	for r in rooms:
		if (r as Rect2i).has_point(c):
			return true
	return false

func _furn_excluded(c: Vector2i, door_zone: Dictionary, used: Dictionary, start_cell: Vector2i) -> bool:
	if door_zone.has(c) or used.has(c):
		return true
	if maxi(absi(c.x - start_cell.x), absi(c.y - start_cell.y)) <= 2:
		return true
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if door_zone.has(c + Vector2i(dx, dy)):
				return true
	return false

func _place_furniture(c: Vector2i, tile: int, used: Dictionary) -> void:
	used[c] = true
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			used[c + Vector2i(dx, dy)] = true
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = (Vector2(c) + Vector2(0.5, 0.5)) * TILE
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	cs.shape = rect
	body.add_child(cs)
	body.add_child(_furn_sprite(tile))
	add_child(body)
	furniture_nodes.append(body)
	blocked_cells[c] = true

func _furn_sprite(tile: int) -> Sprite2D:
	var at := AtlasTexture.new()
	at.atlas = FURN_TEX
	at.region = Rect2(tile * TILE, 0, TILE, TILE)
	var spr := Sprite2D.new()
	spr.texture = at
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr

func _place_deco(c: Vector2i, tile: int, used: Dictionary) -> void:
	used[c] = true
	var deco := Node2D.new()
	deco.position = (Vector2(c) + Vector2(0.5, 0.5)) * TILE
	deco.add_child(_furn_sprite(tile))
	add_child(deco)
	furniture_nodes.append(deco)

func _is_solid_wall(c: Vector2i, floor_set: Dictionary, map_w: int, map_h: int) -> bool:
	# A real painted wall: in bounds, not floor, actually drawn.
	if c.x < 0 or c.y < 0 or c.x >= map_w or c.y >= map_h:
		return false
	if floor_set.has(c):
		return false
	return tile_map.get_cell_source_id(c) != -1

func _open_room_cell(c: Vector2i, floor_set: Dictionary, corridor_set: Dictionary, rooms: Array) -> bool:
	return floor_set.has(c) and not corridor_set.has(c) and _room_at(c, rooms)

func _place_furniture_pass(floor_set: Dictionary, corridor_set: Dictionary, rooms: Array, _wave_number: int, map_w: int, map_h: int) -> Dictionary:
	if rooms.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var first: Rect2i = rooms[0]
	var start_cell := Vector2i(int(first.position.x + first.size.x * 0.5), int(first.position.y + first.size.y * 0.5))
	var door_zone := {}
	for cell in floor_set:
		var c: Vector2i = cell
		if corridor_set.has(c) or not _room_at(c, rooms):
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if corridor_set.has(c + d):
				door_zone[c] = true
				break
	var used := {}
	for cell in floor_set:
		var c: Vector2i = cell
		if corridor_set.has(c) or not _room_at(c, rooms) or _furn_excluded(c, door_zone, used, start_cell):
			continue
		var e: Vector2i = c + Vector2i(1, 0)
		var n: Vector2i = c + Vector2i(0, -1)
		var s: Vector2i = c + Vector2i(0, 1)
		var w: Vector2i = c + Vector2i(-1, 0)
		var wall_e: bool = _is_solid_wall(e, floor_set, map_w, map_h)
		var wall_n: bool = _is_solid_wall(n, floor_set, map_w, map_h)
		var wall_w: bool = _is_solid_wall(w, floor_set, map_w, map_h)
		var wall_e2n: bool = _is_solid_wall(e + Vector2i(0, -1), floor_set, map_w, map_h)
		var wall_e2s: bool = _is_solid_wall(e + Vector2i(0, 1), floor_set, map_w, map_h)
		if wall_e and wall_e2n and wall_e2s and _open_room_cell(n, floor_set, corridor_set, rooms) and _open_room_cell(s, floor_set, corridor_set, rooms) and rng.randf() < 0.35:
			_place_furniture(c, FURN_CABINETS[rng.randi() % FURN_CABINETS.size()], used)
		elif wall_n and wall_w and _open_room_cell(e, floor_set, corridor_set, rooms) and _open_room_cell(s, floor_set, corridor_set, rooms) and rng.randf() < 0.5:
			_place_furniture(c, FURN_CORNER, used)
	for ri in range(rooms.size()):
		if rng.randf() > 0.6:
			continue
		var room: Rect2i = rooms[ri]
		for attempt in range(6):
			var px: int = room.position.x + rng.randi() % maxi(room.size.x - 1, 1)
			var py: int = room.position.y + rng.randi() % maxi(room.size.y - 1, 1)
			var patch := [Vector2i(px, py), Vector2i(px + 1, py), Vector2i(px, py + 1), Vector2i(px + 1, py + 1)]
			var ok := true
			for pc in patch:
				if not floor_set.has(pc) or corridor_set.has(pc) or not _room_at(pc, rooms) or _furn_excluded(pc, door_zone, used, start_cell):
					ok = false
					break
			if ok:
				for dx in range(-1, 3):
					for dy in range(-1, 3):
						if dx in [-1, 2] or dy in [-1, 2]:
							if not floor_set.has(Vector2i(px + dx, py + dy)):
								ok = false
								break
					if not ok:
						break
			if ok:
				for pc in patch:
					_place_deco(pc, FURN_TABLES[rng.randi() % FURN_TABLES.size()], used)
				break
	var walls := {}
	for cell in floor_set:
		var c: Vector2i = cell
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var w: Vector2i = c + Vector2i(dx, dy)
				if not floor_set.has(w):
					walls[w] = true
	for w in walls:
		var wc: Vector2i = w
		var south: Vector2i = wc + Vector2i(0, 1)
		if used.has(wc) or not _is_solid_wall(wc, floor_set, map_w, map_h):
			continue
		if not _is_solid_wall(wc + Vector2i(-1, 0), floor_set, map_w, map_h):
			continue
		if not _is_solid_wall(wc + Vector2i(1, 0), floor_set, map_w, map_h):
			continue
		if not _is_solid_wall(wc + Vector2i(-2, 0), floor_set, map_w, map_h):
			continue
		if not _is_solid_wall(wc + Vector2i(2, 0), floor_set, map_w, map_h):
			continue
		if not _is_solid_wall(wc + Vector2i(0, -1), floor_set, map_w, map_h):
			continue
		if not _open_room_cell(south, floor_set, corridor_set, rooms):
			continue
		if not _open_room_cell(south + Vector2i(-1, 0), floor_set, corridor_set, rooms):
			continue
		if not _open_room_cell(south + Vector2i(1, 0), floor_set, corridor_set, rooms):
			continue
		var clash := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if used.has(wc + Vector2i(dx, dy)):
					clash = true
					break
			if clash:
				break
		if clash:
			continue
		if rng.randf() < 0.18:
			_place_deco(wc, FURN_DOOR, used)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					used[wc + Vector2i(dx, dy)] = true
	return used

func _deco_spacing_ok(deco_used: Dictionary, w: Vector2i, horizontal: bool) -> bool:
	if horizontal:
		return not deco_used.has(w + Vector2i(-1, 0)) and not deco_used.has(w + Vector2i(1, 0))
	return not deco_used.has(w + Vector2i(0, -1)) and not deco_used.has(w + Vector2i(0, 1))

func _straight_run(w: Vector2i, horizontal: bool, floor_set: Dictionary, map_w: int, map_h: int) -> bool:
	for k in [1, 2]:
		var a: Vector2i = w + Vector2i(k, 0) if horizontal else w + Vector2i(0, k)
		var b: Vector2i = w + Vector2i(-k, 0) if horizontal else w + Vector2i(0, -k)
		if not _is_solid_wall(a, floor_set, map_w, map_h):
			return false
		if not _is_solid_wall(b, floor_set, map_w, map_h):
			return false
	return true

func _wide_window_ok(e2: Vector2i, map_w: int, map_h: int, floor_set: Dictionary, reserved: Dictionary, deco_used: Dictionary) -> bool:
	if not _in_map(e2, map_w, map_h):
		return false
	if floor_set.has(e2):
		return false
	if tile_map.get_cell_source_id(e2) == -1:
		return false
	if reserved.has(e2) or deco_used.has(e2):
		return false
	if not _is_solid_wall(e2 + Vector2i(1, 0), floor_set, map_w, map_h):
		return false
	if not _is_solid_wall(e2 + Vector2i(2, 0), floor_set, map_w, map_h):
		return false
	if not floor_set.has(e2 + Vector2i(0, -1)) and not floor_set.has(e2 + Vector2i(0, 1)):
		return false
	if deco_used.has(e2 + Vector2i(1, 0)):
		return false
	if deco_used.has(e2 + Vector2i(-2, 0)):
		return false
	return true

func _tall_window_ok(v2: Vector2i, map_w: int, map_h: int, floor_set: Dictionary, reserved: Dictionary, deco_used: Dictionary) -> bool:
	if not _in_map(v2, map_w, map_h):
		return false
	if floor_set.has(v2):
		return false
	if tile_map.get_cell_source_id(v2) == -1:
		return false
	if reserved.has(v2) or deco_used.has(v2):
		return false
	var f_e: bool = floor_set.has(v2 + Vector2i(1, 0))
	var f_w: bool = floor_set.has(v2 + Vector2i(-1, 0))
	if f_e == f_w:
		return false
	if not _is_solid_wall(v2 + Vector2i(0, 2), floor_set, map_w, map_h):
		return false
	if deco_used.has(v2 + Vector2i(0, 1)):
		return false
	return true

func _place_deco_pass(floor_set: Dictionary, map_w: int, map_h: int, reserved: Dictionary) -> void:
	# Wall dressing only in the middle of straight wall runs, with a gap
	# between pieces, never over furniture doors: ends, corners and
	# crossings keep their autotiled art so nothing looks torn.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var deco_used := {}
	for cell in floor_set:
		var c: Vector2i = cell
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var w: Vector2i = c + d
			if floor_set.has(w) or not _in_map(w, map_w, map_h):
				continue
			if tile_map.get_cell_source_id(w) == -1:
				continue
			if reserved.has(w) or deco_used.has(w):
				continue
			var straight_h: bool = _straight_run(w, true, floor_set, map_w, map_h)
			var straight_v: bool = _straight_run(w, false, floor_set, map_w, map_h)
			if straight_h == straight_v:
				continue
			var f_n: bool = floor_set.has(w + Vector2i(0, -1))
			var f_s: bool = floor_set.has(w + Vector2i(0, 1))
			var f_e: bool = floor_set.has(w + Vector2i(1, 0))
			var f_w: bool = floor_set.has(w + Vector2i(-1, 0))
			var roll: float = rng.randf()
			if straight_h and (f_n or f_s) and _deco_spacing_ok(deco_used, w, true):
				var e2: Vector2i = w + Vector2i(1, 0)
				if roll < 0.14 and _wide_window_ok(e2, map_w, map_h, floor_set, reserved, deco_used):
					tile_map.set_cell(w, 0, Vector2i(DECO_WIDE_LEFT, 0))
					tile_map.set_cell(e2, 0, Vector2i(DECO_WIDE_RIGHT, 0))
					deco_used[w] = true
					deco_used[e2] = true
			elif straight_v and (f_e != f_w) and _deco_spacing_ok(deco_used, w, false):
				var v2: Vector2i = w + Vector2i(0, 1)
				if roll < 0.12 and _tall_window_ok(v2, map_w, map_h, floor_set, reserved, deco_used):
					tile_map.set_cell(w, 0, Vector2i(DECO_WINDOW_TOP, 0))
					tile_map.set_cell(v2, 0, Vector2i(DECO_WINDOW_BOTTOM, 0))
					deco_used[w] = true
					deco_used[v2] = true

func _sanitize_deco(floor_set: Dictionary, map_w: int, map_h: int) -> void:
	# Last line of defense: no matter what placed a tile (deco pass,
	# autotiler, future edits), single windows and banned fragments can
	# never survive to the screen. Broken units revert to plain wall.
	var fixed := 0
	for c in tile_map.get_used_cells():
		var a: Vector2i = tile_map.get_cell_atlas_coords(c)
		if a == Vector2i(10, 0) or a == Vector2i(11, 0) or a == Vector2i(12, 0) or a == Vector2i(13, 0):
			tile_map.set_cell(c, 0, PLAIN_WALL)
			fixed += 1
	for c in tile_map.get_used_cells():
		var a2: Vector2i = tile_map.get_cell_atlas_coords(c)
		if a2 == Vector2i(8, 0):
			var e2: Vector2i = c + Vector2i(1, 0)
			if not _deco_unit_ok(c, e2, true, floor_set, map_w, map_h):
				tile_map.set_cell(c, 0, PLAIN_WALL)
				tile_map.set_cell(e2, 0, PLAIN_WALL)
				fixed += 1
		elif a2 == Vector2i(9, 0):
			if tile_map.get_cell_atlas_coords(c + Vector2i(-1, 0)) != Vector2i(8, 0):
				tile_map.set_cell(c, 0, PLAIN_WALL)
				fixed += 1
		elif a2 == Vector2i(6, 0):
			var v2: Vector2i = c + Vector2i(0, 1)
			if tile_map.get_cell_atlas_coords(v2) != Vector2i(7, 0):
				tile_map.set_cell(c, 0, PLAIN_WALL)
				fixed += 1
			elif not _deco_unit_ok(c, v2, false, floor_set, map_w, map_h):
				tile_map.set_cell(c, 0, PLAIN_WALL)
				tile_map.set_cell(v2, 0, PLAIN_WALL)
				fixed += 1
		elif a2 == Vector2i(7, 0):
			if tile_map.get_cell_atlas_coords(c + Vector2i(0, -1)) != Vector2i(6, 0):
				tile_map.set_cell(c, 0, PLAIN_WALL)
				fixed += 1
	if fixed > 0:
		print("[deco] sanitized ", fixed, " broken tiles")

func _deco_unit_ok(c: Vector2i, c2: Vector2i, horizontal: bool, floor_set: Dictionary, map_w: int, map_h: int) -> bool:
	for k in [-2, -1, 0, 1, 2, 3]:
		var cell: Vector2i = c + Vector2i(k, 0) if horizontal else c + Vector2i(0, k)
		if not _is_solid_wall(cell, floor_set, map_w, map_h):
			return false
	for cell in [c, c2]:
		var f_a: bool = floor_set.has(cell + (Vector2i(0, -1) if horizontal else Vector2i(1, 0)))
		var f_b: bool = floor_set.has(cell + (Vector2i(0, 1) if horizontal else Vector2i(-1, 0)))
		if horizontal:
			if not f_a and not f_b:
				return false
		elif f_a == f_b:
			return false
	return true

func _in_map(c: Vector2i, map_w: int, map_h: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map_w and c.y < map_h

func clamp_to_map(pos: Vector2, margin: float = 20.0) -> Vector2:
	if map_bounds_px.size.x <= 0.0:
		return pos
	return Vector2(
		clampf(pos.x, map_bounds_px.position.x + margin, map_bounds_px.position.x + map_bounds_px.size.x - margin),
		clampf(pos.y, map_bounds_px.position.y + margin, map_bounds_px.position.y + map_bounds_px.size.y - margin))

func spawn_pickup(pickup_type: String, amount: int, pos: Vector2) -> void:
	if pickup_scene == null:
		return
	var drop: Pickup = pickup_scene.instantiate() as Pickup
	if drop == null:
		return
	add_child(drop)
	drop.global_position = clamp_to_map(pos)
	drop.set_pickup_type(pickup_type, amount)

func notify_enemy_killed(xp: int, ammo: int, heal: int, heal_roll: float, pos: Vector2) -> void:
	# XP always drops; ammo and heal have pity guarantees so dry
	# streaks can never stretch past a few kills.
	spawn_pickup("xp", xp, pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)))
	kills_since_ammo += 1
	kills_since_heal += 1
	if randf() < 0.5 or kills_since_ammo >= 3:
		kills_since_ammo = 0
		spawn_pickup("ammo", ammo, pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)))
	if randf() < heal_roll or kills_since_heal >= 8:
		kills_since_heal = 0
		spawn_pickup("heal", heal, pos + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_F9 and not outro_running:
			print("[outro] F9: jump to floor 40")
			wave_manager.current_wave = 39
			begin_wave()
			wave_manager.to_spawn = 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.has_method("die"):
					e.call("die")
			return
		if (event as InputEventKey).keycode == KEY_F12 and not outro_running:
			if player != null and is_instance_valid(player) and player.gun != null:
				while player.gun.can_tier_up():
					player.gun.upgrade_tier()
				player.current_weapon = "minigun"
				print("[cheat] F12: minigun equipped")
			return
	if outro_running:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_outro_skip = true
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_outro_skip = true
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	if pause_menu == null:
		return
	if pause_menu.visible:
		pause_menu.call("_on_continue_pressed")
	else:
		pause_menu.call("show_pause")

func _on_wave_ended(_wave_number: int) -> void:
	get_tree().call_group("enemies", "queue_free")
	get_tree().call_group("bullets", "queue_free")
	get_tree().call_group("pickups", "queue_free")
	get_tree().call_group("corpses", "queue_free")

func show_death() -> void:
	if death_screen != null and death_screen.has_method("show_death"):
		death_screen.call("show_death")

func _on_upgrade_phase(choices: Array[Dictionary]) -> void:
	if outro_running:
		return
	# Breathe between the last kill and the reward screen so stray
	# attack clicks can't insta-pick an upgrade.
	await get_tree().create_timer(0.9).timeout
	if outro_running:
		return
	if not is_instance_valid(self) or upgrade_ui == null:
		return
	upgrade_ui.show_upgrades(choices, player.stats, player.katana, player.gun, wave_manager.get_current_wave())

func _on_upgrade_selected(choice: Dictionary) -> void:
	match String(choice.get("type", "")):
		"bonus":
			if String(choice.get("bonus", "")) == "hp":
				player.grow_max_hp()
			elif String(choice.get("bonus", "")) == "katana":
				player.upgrade_katana()
			elif String(choice.get("bonus", "")) == "gun":
				player.upgrade_gun_tier()
		"stat":
			player.upgrade_stat(String(choice.get("stat", "")))
		"weapon":
			if String(choice.get("weapon", "")) == "katana":
				player.upgrade_katana()

	call_deferred("_start_next_wave_delayed")

func _start_next_wave_delayed() -> void:
	await get_tree().create_timer(0.9).timeout
	if outro_running:
		return
	if is_instance_valid(self):
		begin_wave()

func _on_final_floor_cleared() -> void:
	if outro_running:
		return
	outro_running = true
	_start_outro_phase1()

func _start_outro_phase1() -> void:
	player.controls_locked = true
	player.velocity = Vector2.ZERO
	get_tree().call_group("bullets", "queue_free")
	GameManager.arm_outro_watchdog()
	upgrade_ui.visible = false
	print("[outro] phase 1: drive to center")
	var center: Vector2 = snap_to_floor(map_bounds_px.get_center())
	await _drive_player_to(center)
	_plant_bomb(player.global_position)
	print("[outro] bomb planted, drive to exit")
	if not _outro_skip:
		await get_tree().create_timer(0.5).timeout
	var exit: Vector2 = snap_to_floor(_nearest_edge_point(player.global_position))
	await _drive_player_to(exit)
	player.velocity = Vector2.ZERO
	print("[outro] fade out, cutscene next")
	await _fade_out(0.25 if _outro_skip else 0.8)
	GameManager.play_outro_cutscene()

func _drive_los(a: Vector2, b: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(a, b, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func los_wide(a: Vector2, b: Vector2, radius: float = 12.0) -> bool:
	# Line-of-sight that respects body width: a zero-width ray happily
	# grazes corners the body then wedges into. Check center + both sides.
	var d: Vector2 = b - a
	if d.length() < 1.0:
		return true
	var side := Vector2(-d.y, d.x).normalized() * radius * 0.8
	var space := get_world_2d().direct_space_state
	for off in [Vector2.ZERO, side, -side]:
		var query := PhysicsRayQueryParameters2D.create(a + off, b + off, 1)
		if not space.intersect_ray(query).is_empty():
			return false
	return true

func probe_side(pos: Vector2, dir: Vector2, fallback: float) -> float:
	# Which perpendicular side has more open space? Used to pick an
	# unstick direction instead of blindly flipping (which jitters).
	if dir.length() < 0.01:
		return fallback
	var perp := Vector2(-dir.y, dir.x).normalized()
	var space := get_world_2d().direct_space_state
	var clear_l: float = 26.0
	var q := PhysicsRayQueryParameters2D.create(pos, pos + perp * 26.0, 1)
	var hit_l: Dictionary = space.intersect_ray(q)
	if not hit_l.is_empty():
		clear_l = pos.distance_to(hit_l["position"])
	var clear_r: float = 26.0
	q = PhysicsRayQueryParameters2D.create(pos, pos - perp * 26.0, 1)
	var hit_r: Dictionary = space.intersect_ray(q)
	if not hit_r.is_empty():
		clear_r = pos.distance_to(hit_r["position"])
	if absf(clear_l - clear_r) < 4.0:
		return fallback
	return 1.0 if clear_l > clear_r else -1.0

func simplify_path_wide(pts: PackedVector2Array, radius: float = 12.0) -> PackedVector2Array:
	if pts.size() <= 3:
		return pts
	var out := PackedVector2Array()
	var i := 0
	out.append(pts[0])
	while i < pts.size() - 1:
		var j: int = mini(i + 12, pts.size() - 1)
		while j > i + 1 and not los_wide(pts[i], pts[j], radius):
			j -= 1
		out.append(pts[j])
		i = j
	return out

func inflate_path(pts: PackedVector2Array, radius: float = 12.0) -> PackedVector2Array:
	# Push interior waypoints away from nearby walls so the body stops
	# grinding doorframes and corners it was aimed straight through.
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
		Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]
	var space := get_world_2d().direct_space_state
	var reach: float = radius + 12.0
	for i in range(1, pts.size() - 1):
		var p: Vector2 = pts[i]
		var push := Vector2.ZERO
		for d in dirs:
			var query := PhysicsRayQueryParameters2D.create(p, p + d * reach, 1)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				var dist: float = p.distance_to(hit["position"])
				if dist < reach:
					push -= d * (1.0 - dist / reach)
		if push.length() > 0.01:
			out.append(p + push.normalized() * minf(push.length() * 8.0, 10.0))
		else:
			out.append(p)
	out.append(pts[pts.size() - 1])
	return out

func find_smooth_path(from_px: Vector2, to_px: Vector2, radius: float = 12.0) -> PackedVector2Array:
	return inflate_path(simplify_path_wide(find_path(from_px, to_px), radius), radius)

func _drive_player_to(target: Vector2) -> void:
	var pts: PackedVector2Array = find_smooth_path(player.global_position, target, 12.0)
	if pts.is_empty():
		pts = PackedVector2Array([target])
	var speed: float = player.stats.speed if player.stats != null else 250.0
	print("[outro] drive: ", pts.size(), " waypoints, dist=", snappedf(player.global_position.distance_to(target), 1.0))
	var t: float = 0.0
	var idx: int = 0
	var frames: int = 0
	var last_pos: Vector2 = player.global_position
	var still: int = 0
	var sidestep: int = 0
	var backup: int = 0
	var side_sign: float = 1.0
	var repathed: int = 0
	var stage: int = 2
	var grace: int = 0
	while idx < pts.size():
		if not is_instance_valid(player):
			return
		var pos: Vector2 = player.global_position
		while idx < pts.size() and pos.distance_to(pts[idx]) < 20.0:
			idx += 1
		if idx >= pts.size():
			break
		var goal: Vector2 = pts[idx]
		var li: int = idx
		while li + 1 < pts.size() and pos.distance_to(pts[li + 1]) < 40.0 and los_wide(pos, pts[li + 1], 10.0):
			li += 1
			goal = pts[li]
		var to_goal: Vector2 = goal - pos
		if to_goal.length() < 1.0:
			idx = li + 1
			continue
		var dir: Vector2 = to_goal.normalized()
		var spd: float = speed * (0.45 if pos.distance_to(target) < 48.0 else 1.0)
		if player.velocity.length() > 10.0 and absf(dir.angle_to(player.velocity.normalized())) > 1.0:
			spd *= 0.6
		if backup > 0:
			backup -= 1
			dir = -dir
			spd = speed * 0.7
		elif sidestep > 0:
			sidestep -= 1
			var perp := Vector2(-dir.y, dir.x) * side_sign
			dir = (dir * 0.15 + perp * 0.95).normalized()
		player.velocity = dir * spd
		player.rotation = dir.angle() + PI * 0.5
		player.move_and_slide()
		t += get_physics_process_delta_time()
		frames += 1
		if grace > 0:
			grace -= 1
			still = 0
		elif player.global_position.distance_to(last_pos) < 3.0:
			still += 1
		else:
			still = 0
		last_pos = player.global_position
		if still > 45:
			still = 0
			grace = 20
			side_sign = probe_side(pos, dir, side_sign)
			stage = (stage + 1) % 3
			if stage == 0:
				backup = 20
				print("[outro] drive backing out of pocket")
			elif stage == 1 or repathed >= 3:
				sidestep = 40
				print("[outro] drive sidestepping around obstacle")
			else:
				repathed += 1
				pts = find_smooth_path(player.global_position, target, 12.0)
				if pts.is_empty():
					pts = PackedVector2Array([target])
				idx = 0
				print("[outro] drive repathed from current pos")
		if frames % 180 == 0:
			print("[outro] driving... t=", snappedf(t, 0.1), " wp=", idx, "/", pts.size(), " paused=", get_tree().paused)
		if t > 14.0 or _outro_skip or frames > 1200:
			break
		await get_tree().physics_frame
	player.velocity = Vector2.ZERO
	if is_instance_valid(player) and player.global_position.distance_to(target) > 24.0:
		print("[outro] drive fallback: teleport to target")
		player.global_position = target
	print("[outro] drive leg done")

func _plant_bomb(at: Vector2) -> void:
	var bomb := Sprite2D.new()
	bomb.add_to_group("outro_bomb")
	bomb.texture = BOMB_TEX
	bomb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bomb.scale = Vector2(3.0, 3.0)
	bomb.z_index = 5
	add_child(bomb)
	bomb.global_position = at

func _nearest_edge_point(from: Vector2) -> Vector2:
	var b: Rect2 = map_bounds_px
	if b.size.x <= 0.0:
		return from + Vector2(400.0, 0.0)
	var top: float = b.position.y
	var bottom: float = b.position.y + b.size.y
	var left: float = b.position.x
	var right: float = b.position.x + b.size.x
	var cands: Array[Vector2] = [
		Vector2(left, clampf(from.y, top, bottom)),
		Vector2(right, clampf(from.y, top, bottom)),
		Vector2(clampf(from.x, left, right), top),
		Vector2(clampf(from.x, left, right), bottom),
	]
	var best: Vector2 = cands[0]
	var best_d: float = from.distance_to(best)
	for c in cands:
		var d: float = from.distance_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best

func _fade_out(duration: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, duration)
	await tw.finished

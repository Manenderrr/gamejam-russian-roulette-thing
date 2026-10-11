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

var pickup_scene: PackedScene = load("res://src/level/pickup.tscn")
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
const DECO_WINDOW := 6
const DECO_VENTS: Array[int] = [8, 9, 10]
const DECO_DOOR := 11
const DECO_MISC: Array[int] = [7, 12, 13]
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

	upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	begin_wave()

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

	# Fill background with ground texture (32px tile, so 2x2 cells per tile map cell)
	for x in range(-2, map_w + 2):
		for y in range(-2, map_h + 2):
			bg_tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

	_place_furniture_pass(floor_set, corridor_set, rooms, wave_number, map_w, map_h)
	_place_deco_pass(floor_set, map_w, map_h)
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

func _place_furniture_pass(floor_set: Dictionary, corridor_set: Dictionary, rooms: Array, _wave_number: int, map_w: int, map_h: int) -> void:
	if rooms.is_empty():
		return
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
		var w: Vector2i = c + Vector2i(-1, 0)
		var wall_e: bool = _is_solid_wall(e, floor_set, map_w, map_h)
		var wall_n: bool = _is_solid_wall(n, floor_set, map_w, map_h)
		var wall_w: bool = _is_solid_wall(w, floor_set, map_w, map_h)
		if wall_e and rng.randf() < 0.35:
			_place_furniture(c, FURN_CABINETS[rng.randi() % FURN_CABINETS.size()], used)
		elif wall_n and wall_w and rng.randf() < 0.5:
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
		if not floor_set.has(south) or corridor_set.has(south) or not _room_at(south, rooms):
			continue
		if not _is_solid_wall(wc + Vector2i(0, -1), floor_set, map_w, map_h):
			continue
		if rng.randf() < 0.12:
			_place_deco(wc, FURN_DOOR, used)

func _place_deco_pass(floor_set: Dictionary, map_w: int, map_h: int) -> void:
	# Wall dressing from the tileset list, matched to the wall run:
	# horizontal grates only on horizontal runs, the tall window only on
	# vertical runs, never on single-cell nubs. Runs after the terrain
	# update so the autotiler never overwrites them.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for cell in floor_set:
		var c: Vector2i = cell
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var w: Vector2i = c + d
			if floor_set.has(w) or not _in_map(w, map_w, map_h):
				continue
			if tile_map.get_cell_source_id(w) == -1:
				continue
			var run_e: bool = _is_solid_wall(w + Vector2i(1, 0), floor_set, map_w, map_h)
			var run_w: bool = _is_solid_wall(w + Vector2i(-1, 0), floor_set, map_w, map_h)
			var run_n: bool = _is_solid_wall(w + Vector2i(0, -1), floor_set, map_w, map_h)
			var run_s: bool = _is_solid_wall(w + Vector2i(0, 1), floor_set, map_w, map_h)
			var horiz: bool = run_e or run_w
			var vert: bool = run_n or run_s
			if not horiz and not vert:
				continue
			var f_n: bool = floor_set.has(w + Vector2i(0, -1))
			var f_s: bool = floor_set.has(w + Vector2i(0, 1))
			var f_e: bool = floor_set.has(w + Vector2i(1, 0))
			var f_w: bool = floor_set.has(w + Vector2i(-1, 0))
			var roll: float = rng.randf()
			if horiz and (f_n or f_s):
				if roll < 0.025 and f_s:
					tile_map.set_cell(w, 0, Vector2i(DECO_DOOR, 0))
				elif roll < 0.09:
					tile_map.set_cell(w, 0, Vector2i(DECO_VENTS[rng.randi() % DECO_VENTS.size()], 0))
				elif roll < 0.13:
					tile_map.set_cell(w, 0, Vector2i(DECO_MISC[rng.randi() % DECO_MISC.size()], 0))
			elif vert and not horiz and (f_e or f_w):
				if roll < 0.09:
					tile_map.set_cell(w, 0, Vector2i(DECO_WINDOW, 0))
				elif roll < 0.13:
					tile_map.set_cell(w, 0, Vector2i(DECO_MISC[rng.randi() % DECO_MISC.size()], 0))

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
	# Breathe between the last kill and the reward screen so stray
	# attack clicks can't insta-pick an upgrade.
	await get_tree().create_timer(0.9).timeout
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
	if is_instance_valid(self):
		begin_wave()

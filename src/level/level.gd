extends Node2D
class_name GameLevel

const TILE: int = 16
const WALL_CELL := Vector2i(4, 0)

@onready var tile_map: TileMapLayer = $TileMapLayer
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
	# Fresh roguelike floor every wave; player keeps stats and loot.
	_build_floor(wave_manager.get_current_wave() + 1)
	wave_manager.set_arena(wave_manager.spawn_rooms, map_bounds_px)
	wave_manager.safe_center = player.global_position
	wave_manager.call("_start_next_wave")

const FLOOR_PLAIN: int = 0
const TRIM_NORTH: int = 1
const TRIM_SE: int = 2

func _build_floor(wave_number: int) -> void:
	tile_map.clear()
	var gen := RoomGenerator.new()
	var result: Dictionary = gen.generate(84, 84, 10, 6, 13, wave_number * 7919 + 13)
	var rooms: Array = result["rooms"]
	var floor_set: Dictionary = result["floors"]
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
		astar.add_point(_cell_id(c), Vector2(c))
	for cell in floor_set:
		var c: Vector2i = cell
		var e: Vector2i = c + Vector2i(1, 0)
		var s: Vector2i = c + Vector2i(0, 1)
		if floor_set.has(e):
			astar.connect_points(_cell_id(c), _cell_id(e))
		if floor_set.has(s):
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

func show_death() -> void:
	if death_screen != null and death_screen.has_method("show_death"):
		death_screen.call("show_death")

func _on_upgrade_phase(choices: Array[Dictionary]) -> void:
	upgrade_ui.show_upgrades(choices, player.stats, player.katana, player.gun, wave_manager.get_current_wave())

func _on_upgrade_selected(choice: Dictionary) -> void:
	match String(choice.get("type", "")):
		"bonus":
			if String(choice.get("bonus", "")) == "hp":
				player.grow_max_hp()
			elif String(choice.get("bonus", "")) == "katana":
				player.upgrade_katana()
		"stat":
			player.upgrade_stat(String(choice.get("stat", "")))
		"weapon":
			if String(choice.get("weapon", "")) == "katana":
				player.upgrade_katana()
			elif String(choice.get("weapon", "")) == "gun":
				player.upgrade_gun()

	call_deferred("_start_next_wave_delayed")

func _start_next_wave_delayed() -> void:
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(self):
		begin_wave()

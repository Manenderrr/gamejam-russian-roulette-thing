extends Node
class_name WaveManager

# Clear-the-floor goal: each wave spawns a fixed quota of enemies and ends
# when every one of them is dead. No timer.

signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal upgrade_phase_started(choices: Array[Dictionary])

@export var base_enemies_per_wave: int = 10
@export var enemy_increase_per_wave: int = 3
@export var max_concurrent: int = 18
@export var spawn_interval: float = 0.7
@export var tile_size: int = 16

var current_wave: int = 0
var is_wave_active: bool = false
var enemies_alive: int = 0
var to_spawn: int = 0
var spawn_timer: float = 0.0

var enemy_scenes: Array[PackedScene] = []
var spawn_rooms: Array = []
var map_bounds_px: Rect2 = Rect2()
var player: Node2D = null
# No spawns inside this radius around the player start: nobody gets
# punched before they can react.
var safe_center: Vector2 = Vector2.ZERO
var safe_radius: float = 420.0

func _ready() -> void:
	pass

func start_waves(player_node: Node2D, enemy_scenes_array: Array[PackedScene]) -> void:
	player = player_node
	enemy_scenes = enemy_scenes_array
	current_wave = 0
	is_wave_active = false
	enemies_alive = 0
	to_spawn = 0
	# The level builds the floor first, then kicks off wave 1 itself.

func set_arena(room_list: Array, bounds_px: Rect2) -> void:
	spawn_rooms = room_list
	map_bounds_px = bounds_px

func _wave_quota(wave: int) -> int:
	if wave == 5:
		return 1
	return base_enemies_per_wave + (wave - 1) * enemy_increase_per_wave

func _get_available_enemies() -> Array[PackedScene]:
	var available: Array[PackedScene] = []
	match current_wave:
		1:
			if enemy_scenes.size() > 0:
				available.append(enemy_scenes[0])
		2:
			if enemy_scenes.size() > 1:
				available.append(enemy_scenes[1])
		3, 4:
			if enemy_scenes.size() > 0:
				available.append(enemy_scenes[0])
			if enemy_scenes.size() > 1:
				available.append(enemy_scenes[1])
		5:
			if enemy_scenes.size() > 2:
				available.append(enemy_scenes[2])
		_:
			available = enemy_scenes.duplicate()
	if available.is_empty() and enemy_scenes.size() > 0:
		available = enemy_scenes.duplicate()
	return available

func _start_next_wave() -> void:
	current_wave += 1
	is_wave_active = true
	enemies_alive = 0
	to_spawn = _wave_quota(current_wave)
	spawn_timer = 0.0

	# Opening burst so the floor feels alive immediately.
	var burst: int = mini(6, to_spawn)
	for i in range(burst):
		_spawn_enemy()
		to_spawn -= 1

	wave_started.emit(current_wave)

func _random_room_point() -> Vector2:
	if spawn_rooms.is_empty() or player == null:
		return player.global_position + Vector2(220, 0) if player != null else Vector2.ZERO
	var pos := _pick_room_point()
	for i in range(6):
		if pos.distance_to(safe_center) >= safe_radius:
			break
		pos = _pick_room_point()
	if pos.distance_to(safe_center) < safe_radius:
		pos = _farthest_room_point()
	return _clamp_to_map(pos)

func _pick_room_point() -> Vector2:
	var room: Rect2i = spawn_rooms[randi() % spawn_rooms.size()]
	var tx: int = room.position.x + randi() % maxi(room.size.x, 1)
	var ty: int = room.position.y + randi() % maxi(room.size.y, 1)
	return Vector2((tx + 0.5) * tile_size, (ty + 0.5) * tile_size)

func _farthest_room_point() -> Vector2:
	var best := _pick_room_point()
	var best_d: float = best.distance_to(safe_center)
	for i in range(8):
		var cand := _pick_room_point()
		var d: float = cand.distance_to(safe_center)
		if d > best_d:
			best_d = d
			best = cand
	return best

func _clamp_to_map(pos: Vector2) -> Vector2:
	if map_bounds_px.size.x <= 0.0:
		return pos
	return Vector2(
		clampf(pos.x, map_bounds_px.position.x, map_bounds_px.position.x + map_bounds_px.size.x),
		clampf(pos.y, map_bounds_px.position.y, map_bounds_px.position.y + map_bounds_px.size.y))

func _spawn_enemy() -> void:
	var available_enemies: Array[PackedScene] = _get_available_enemies()
	if available_enemies.is_empty():
		return

	var enemy_scene: PackedScene = available_enemies[randi() % available_enemies.size()]
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(enemy)
	enemy.global_position = _random_room_point()
	enemies_alive += 1

func _physics_process(delta: float) -> void:
	if not is_wave_active:
		return

	spawn_timer -= delta
	if to_spawn > 0 and spawn_timer <= 0.0 and enemies_alive < max_concurrent:
		_spawn_enemy()
		to_spawn -= 1
		spawn_timer = spawn_interval

func on_enemy_killed() -> void:
	enemies_alive -= 1
	if is_wave_active and to_spawn <= 0 and enemies_alive <= 0:
		_end_wave()

func _end_wave() -> void:
	is_wave_active = false
	wave_ended.emit(current_wave)
	upgrade_phase_started.emit(_generate_upgrade_choices())

func _generate_upgrade_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	choices.append({
		"type": "stat",
		"stat": "health",
		"text": "HP +20",
		"description": "Increase max health by 20"
	})
	choices.append({
		"type": "stat",
		"stat": "speed",
		"text": "Speed +30",
		"description": "Increase movement speed by 30"
	})
	choices.append({
		"type": "stat",
		"stat": "damage",
		"text": "Damage +20%",
		"description": "Increase damage multiplier by 20%"
	})
	return choices

func get_enemies_left() -> int:
	return maxi(enemies_alive, 0) + maxi(to_spawn, 0)

func get_current_wave() -> int:
	return current_wave

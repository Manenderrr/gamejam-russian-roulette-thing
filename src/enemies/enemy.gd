extends CharacterBody2D
class_name Enemy

@export var max_health: float = 100.0
@export var move_speed: float = 150.0
@export var damage: float = 10.0
@export var detection_range: float = 400.0
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 1.0
@export var xp_reward: int = 10
@export var ammo_reward: int = 5
@export var heal_reward: int = 15
@export var heal_chance: float = 0.15

var health: float = 100.0
var attack_timer: float = 0.0
var player: Node2D = null
var sprite: Sprite2D = null
var collision_shape: CollisionShape2D = null

# Animation + facing. Subclasses fill walk/attack textures before super._ready().
var idle_textures: Array[Texture2D] = []
var walk_textures: Array[Texture2D] = []
var attack_textures: Array[Texture2D] = []
var faces_player: bool = true
var anim_fps: float = 7.0
var anim_time: float = 0.0
var anim_frame: int = 0
var attack_anim: float = 0.0
const ATTACK_ANIM_LEN: float = 0.28
var flash_tween: Tween = null
# Wall unstuck: sidestep briefly when shoved into a corner.
var stuck_time: float = 0.0
var sidestep_time: float = 0.0
var sidestep_dir: float = 1.0
var path_points := PackedVector2Array()
var path_index: int = 0
var repath_timer: float = 0.0
const REPATH_INTERVAL: float = 0.4
const WAYPOINT_RADIUS: float = 12.0

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D") as Sprite2D
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	player = get_tree().get_first_node_in_group("player") as Node2D
	repath_timer = randf() * REPATH_INTERVAL

	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = load("res://assets/gfx/enemy/office_plankton/frames/office_plankton_idle.webp") as Texture2D
		add_child(sprite)

	if sprite != null:
		if idle_textures.size() > 0:
			sprite.texture = idle_textures[0]
		elif walk_textures.size() > 0:
			sprite.texture = walk_textures[0]

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or health <= 0.0:
		return

	attack_timer -= delta

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = REPATH_INTERVAL
		_refresh_path()
	var direction: Vector2 = _path_direction()
	if direction == Vector2.ZERO and distance > 1.0:
		direction = to_player / distance

	# Always hunt the player, no matter the distance.
	var wants_to_move: bool = false
	if distance <= attack_range and attack_timer <= 0.0:
		attack()
	elif distance > attack_range:
		wants_to_move = true
		if sidestep_time > 0.0:
			sidestep_time -= delta
			var perp := Vector2(-direction.y, direction.x) * sidestep_dir
			velocity = (direction * 0.4 + perp * 0.9).normalized() * move_speed
		else:
			velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# If we want to move but barely budge, we're wedged: sidestep to unstick.
	if wants_to_move and velocity.length() < 15.0:
		stuck_time += delta
		if stuck_time > 0.7:
			stuck_time = 0.0
			sidestep_time = 0.5
			sidestep_dir *= -1.0
	else:
		stuck_time = 0.0

	if faces_player and player != null and is_instance_valid(player):
		var face_to: Vector2 = velocity if velocity.length() > 10.0 else player.global_position - global_position
		if face_to.length() > 1.0:
			rotation = face_to.angle() + PI * 0.5

	_update_animation(delta)

func _refresh_path() -> void:
	path_points = PackedVector2Array()
	path_index = 0
	if player == null or not is_instance_valid(player):
		return
	var lvl: Node = get_tree().get_first_node_in_group("level")
	if lvl != null and lvl.has_method("find_path"):
		path_points = lvl.call("find_path", global_position, player.global_position)

func _path_direction() -> Vector2:
	while path_index < path_points.size():
		if global_position.distance_to(path_points[path_index]) < WAYPOINT_RADIUS:
			path_index += 1
		else:
			break
	if path_index >= path_points.size():
		return Vector2.ZERO
	var d: Vector2 = path_points[path_index] - global_position
	if d.length() < 1.0:
		return Vector2.ZERO
	return d / d.length()

func _update_animation(delta: float) -> void:
	if sprite == null:
		return
	anim_time += delta
	if attack_anim > 0.0:
		attack_anim -= delta
		if attack_textures.size() > 0:
			var af: int = int(anim_time * 14.0) % attack_textures.size()
			sprite.texture = attack_textures[af]
			return
	if velocity.length() > 10.0 and walk_textures.size() > 0:
		var wf: int = int(anim_time * anim_fps) % walk_textures.size()
		if wf != anim_frame:
			anim_frame = wf
			sprite.texture = walk_textures[wf]
	elif idle_textures.size() > 0:
		anim_frame = 0
		sprite.texture = idle_textures[0]
	elif walk_textures.size() > 0:
		anim_frame = 0
		sprite.texture = walk_textures[0]

func take_damage(amount: float) -> void:
	health -= amount
	_flash_red()
	if health <= 0.0:
		die()

func _flash_red() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func attack() -> void:
	attack_timer = attack_cooldown
	attack_anim = ATTACK_ANIM_LEN
	if player == null or not is_instance_valid(player):
		return
	if not _has_line_of_sight_to(player):
		return
	if player.has_method("take_damage"):
		player.call("take_damage", damage)

func _has_line_of_sight_to(target: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	return space.intersect_ray(query).is_empty()

func die() -> void:
	# Tell the wave tracker first (kill-all goal), then hand the drops to
	# the level (it owns spawn positions and pity guarantees). Death happens
	# inside physics callbacks, so the level call is deferred past the flush.
	get_tree().call_group("wave_manager", "on_enemy_killed")
	var lvl: Node = get_tree().get_first_node_in_group("level")
	if lvl != null:
		lvl.call_deferred("notify_enemy_killed", xp_reward, ammo_reward, heal_reward, heal_chance, global_position)
	queue_free()

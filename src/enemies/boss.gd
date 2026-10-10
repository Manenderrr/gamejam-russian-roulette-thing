extends Enemy
class_name Boss

const IDLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/boss/boss_idle.webp"),
]
const WALK_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/boss/boss_walk1.webp"),
	preload("res://assets/gfx/enemy/boss/boss_walk2.webp"),
]
const ATTACK_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/boss/boss_attack_1.webp"),
	preload("res://assets/gfx/enemy/boss/boss_attack_2.webp"),
	preload("res://assets/gfx/enemy/boss/boss_attack_3.webp"),
]

@export var phase2_health_threshold: float = 0.5
@export var minion_scene: PackedScene
@export var spawn_cooldown: float = 5.0

var spawn_timer: float = 0.0
var in_phase2: bool = false

func _ready() -> void:
	max_health = 500.0
	move_speed = 80.0
	damage = 30.0
	detection_range = 600.0
	attack_range = 80.0
	attack_cooldown = 2.0
	xp_reward = 100
	ammo_reward = 30
	heal_reward = 40
	heal_chance = 0.6
	faces_player = true
	anim_fps = 6.0
	idle_textures = IDLE_FRAMES.duplicate()
	walk_textures = WALK_FRAMES.duplicate()
	attack_textures = ATTACK_FRAMES.duplicate()
	super._ready()

	if sprite != null:
		sprite.scale = Vector2(2.0, 2.0)
	if collision_shape != null:
		collision_shape.scale = Vector2(2.0, 2.0)

func _physics_process(delta: float) -> void:
	spawn_timer -= delta
	super._physics_process(delta)

	if max_health > 0.0 and health / max_health <= phase2_health_threshold and not in_phase2:
		enter_phase2()

	if in_phase2 and spawn_timer <= 0.0 and minion_scene != null:
		spawn_minions()

func enter_phase2() -> void:
	if in_phase2:
		return
	in_phase2 = true
	move_speed = 120.0
	attack_cooldown = 1.0
	# No permanent tint: boss flashes red on hits like everything else.

func spawn_minions() -> void:
	spawn_timer = spawn_cooldown
	var lvl: Node = get_tree().get_first_node_in_group("level")
	var home: Node = lvl if lvl != null else get_tree().root
	for i in range(3):
		var minion: Node2D = minion_scene.instantiate() as Node2D
		if minion == null:
			continue
		home.add_child(minion)
		var angle: float = (float(i) / 3.0) * TAU + randf() * 0.6
		var want: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * 100.0
		if lvl != null and lvl.has_method("snap_to_floor"):
			minion.global_position = lvl.call("snap_to_floor", want)
		else:
			minion.global_position = want

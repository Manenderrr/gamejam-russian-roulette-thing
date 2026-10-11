extends Enemy
class_name OfficePlankton

const IDLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/office_plankton/frames/office_plankton_idle.webp"),
]
const WALK_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/office_plankton/frames/office_plankton_walk1.webp"),
	preload("res://assets/gfx/enemy/office_plankton/frames/office_plankton_walk2.webp"),
]
const ATTACK_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/office_plankton/frames/office_plankton_attack1.webp"),
	preload("res://assets/gfx/enemy/office_plankton/frames/office_plankton_attack2.webp"),
	preload("res://assets/gfx/enemy/office_plankton/frames/office_plankton_attack3.webp"),
]
const CORPSE: Texture2D = preload("res://assets/gfx/enemy/office_plankton/frames/office_plankton_dead_body.webp")

func _ready() -> void:
	max_health = 50.0
	move_speed = 120.0
	damage = 5.0
	detection_range = 300.0
	attack_range = 40.0
	attack_cooldown = 1.5
	xp_reward = 5
	ammo_reward = 2
	idle_textures = IDLE_FRAMES.duplicate()
	walk_textures = WALK_FRAMES.duplicate()
	attack_textures = ATTACK_FRAMES.duplicate()
	corpse_texture = CORPSE
	anim_fps = 7.0
	super._ready()

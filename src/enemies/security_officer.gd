extends Enemy
class_name SecurityOfficer

# Melee puncher (no gun): tougher and meaner than a plankton,
# telegraphs punches with its attack frames.

const IDLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/security_officer/frames/security_officer_idle.webp"),
]
const WALK_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/security_officer/frames/security_officer_walk1.webp"),
	preload("res://assets/gfx/enemy/security_officer/frames/security_officer_walk2.webp"),
]
const ATTACK_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/enemy/security_officer/frames/security_officer_attack1.webp"),
	preload("res://assets/gfx/enemy/security_officer/frames/security_officer_attack2.webp"),
	preload("res://assets/gfx/enemy/security_officer/frames/security_officer_attack3.webp"),
]
const CORPSE: Texture2D = preload("res://assets/gfx/enemy/security_officer/frames/security_officer_dead_body.webp")

func _ready() -> void:
	max_health = 100.0
	move_speed = 110.0
	damage = 12.0
	detection_range = 450.0
	attack_range = 46.0
	attack_cooldown = 1.2
	xp_reward = 15
	ammo_reward = 8
	idle_textures = IDLE_FRAMES.duplicate()
	walk_textures = WALK_FRAMES.duplicate()
	attack_textures = ATTACK_FRAMES.duplicate()
	corpse_texture = CORPSE
	anim_fps = 6.0
	super._ready()

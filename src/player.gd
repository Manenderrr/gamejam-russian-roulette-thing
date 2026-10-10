extends CharacterBody2D
class_name Player

const TEX_IDLE: Texture2D = preload("res://assets/gfx/player/idle.webp")
const TEX_WALK: Texture2D = preload("res://assets/gfx/player/walk_1.webp")
const TEX_SHOOT: Array[Texture2D] = [
	preload("res://assets/gfx/player/shoot_1.webp"),
	preload("res://assets/gfx/player/shoot_2.webp"),
	preload("res://assets/gfx/player/shoot_3.webp"),
]
const SHOOT_ANIM_LEN: float = 0.18

@export var stats: PlayerStats
@export var katana: Weapon
@export var gun: Weapon

@onready var sprite: Sprite2D = $Sprite
@onready var melee_collision: ShapeCast2D = $MeleeCollision

var current_weapon: String = "katana"
var dash_cooldown: float = 0.0
var shoot_anim: float = 0.0
var swing_anim: float = 0.0
const SWING_ANIM_LEN: float = 0.2
var dead: bool = false
var flash_tween: Tween = null

func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
		stats.current_health = stats.max_health

	if katana == null:
		katana = Katana.new()
		katana.slash_scene = load("res://src/weapon/slash.tscn") as PackedScene

	if gun == null:
		gun = Gun.new()
		gun.bullet_scene = load("res://src/weapon/bullet.tscn") as PackedScene

	add_to_group("player")
	if melee_collision != null:
		melee_collision.enabled = false

func _physics_process(delta: float) -> void:
	if stats == null:
		return
	_handle_movement()
	_handle_rotation()
	_handle_dash()
	_update_animation(delta)

	if dash_cooldown > 0.0:
		dash_cooldown -= delta

func _update_animation(delta: float) -> void:
	if sprite == null:
		return
	shoot_anim -= delta
	swing_anim -= delta
	if shoot_anim > 0.0:
		var idx: int = clampi(int((SHOOT_ANIM_LEN - shoot_anim) / 0.06), 0, TEX_SHOOT.size() - 1)
		sprite.texture = TEX_SHOOT[idx]
	elif swing_anim > 0.0:
		sprite.texture = TEX_WALK
	elif velocity.length() > 10.0:
		sprite.texture = TEX_WALK
	else:
		sprite.texture = TEX_IDLE

func _handle_movement() -> void:
	var direction: Vector2 = Input.get_vector("go_left", "go_right", "go_up", "go_down")
	velocity = direction * stats.speed
	move_and_slide()

func _handle_rotation() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	if mouse_pos != global_position:
		rotation = (mouse_pos - global_position).angle() + PI / 2.0

func _handle_dash() -> void:
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		var direction: Vector2 = Input.get_vector("go_left", "go_right", "go_up", "go_down")
		if direction.length() > 0.0:
			velocity = direction.normalized() * stats.speed * 3.0
			move_and_slide()
			dash_cooldown = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("melee") and current_weapon == "katana":
		_attack_katana()
	elif event.is_action_pressed("shoot") and current_weapon == "gun":
		_attack_gun()
	elif event.is_action_pressed("switch_weapon"):
		_switch_weapon()

func _attack_katana() -> void:
	if katana == null or stats == null:
		return
	swing_anim = SWING_ANIM_LEN
	if melee_collision != null:
		melee_collision.enabled = true
		melee_collision.force_shapecast_update()

	var mouse_pos: Vector2 = get_global_mouse_position()
	katana.attack(get_tree().root, global_position, mouse_pos, stats.damage_multiplier, self)

	call_deferred("_disable_melee")

func _disable_melee() -> void:
	if melee_collision != null:
		melee_collision.enabled = false

func _attack_gun() -> void:
	if gun == null or stats == null:
		return
	shoot_anim = SHOOT_ANIM_LEN
	var mouse_pos: Vector2 = get_global_mouse_position()
	gun.attack(get_tree().root, global_position, mouse_pos, stats.damage_multiplier)

func _switch_weapon() -> void:
	if current_weapon == "katana":
		current_weapon = "gun"
	else:
		current_weapon = "katana"
	print("Switched to: ", current_weapon)

func take_damage(amount: float) -> void:
	if stats == null or dead:
		return
	stats.take_damage(amount)
	_flash_red()
	if stats.current_health <= 0.0:
		die()

func _flash_red() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	get_tree().call_group("level", "show_death")

func heal(amount: float) -> void:
	if stats != null:
		stats.heal(amount)

func add_xp(amount: int) -> void:
	if stats == null:
		return
	var leveled_up: bool = stats.add_xp(amount)
	if leveled_up:
		print("Level up! Stat points: ", stats.stat_points)

func add_ammo(amount: int) -> void:
	if gun != null:
		gun.add_ammo(amount)

func upgrade_stat(stat_name: String) -> void:
	if stats == null:
		return
	match stat_name:
		"health":
			stats.upgrade_health()
		"speed":
			stats.upgrade_speed()
		"damage":
			stats.upgrade_damage()

func grow_max_hp(amount: float = 25.0) -> void:
	if stats != null:
		stats.grow_max_hp(amount)

func upgrade_katana() -> void:
	if katana != null:
		katana.upgrade()

func upgrade_gun() -> void:
	if gun != null:
		gun.upgrade()

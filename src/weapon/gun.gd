extends Weapon
class_name Gun

@export var max_ammo: int = 30
@export var fire_rate: float = 0.3
@export var bullet_speed: float = 950.0
@export var bullet_scene: PackedScene
@export var spread: float = 0.1

var current_ammo: int = 30
var last_shot_time: float = 0.0

func _init() -> void:
	weapon_name = "Pistol"
	base_damage = 15.0
	max_level = 5
	current_ammo = max_ammo

func attack(spawn_root: Node, player_global_pos: Vector2, mouse_global_pos: Vector2, damage_mult: float, _wielder: Node2D = null) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < fire_rate:
		return
	if current_ammo <= 0:
		return

	last_shot_time = current_time
	current_ammo -= 1

	if mouse_global_pos == player_global_pos:
		return
	var direction: Vector2 = (mouse_global_pos - player_global_pos).normalized()
	var base_angle: float = direction.angle()
	var actual_angle: float = base_angle + randf_range(-spread, spread)

	if bullet_scene and is_instance_valid(spawn_root):
		var bullet: Bullet = bullet_scene.instantiate() as Bullet
		if bullet == null:
			return
		spawn_root.add_child(bullet)
		# Muzzle offset so the bullet never starts inside the shooter.
		var muzzle: Vector2 = player_global_pos + Vector2(cos(actual_angle), sin(actual_angle)) * 26.0
		bullet.global_position = muzzle
		bullet.rotation = actual_angle
		bullet.set_hostile(false)
		bullet.set_bullet_velocity(Vector2(cos(actual_angle), sin(actual_angle)) * bullet_speed)
		bullet.set_damage(get_damage(damage_mult))

func add_ammo(amount: int) -> void:
	current_ammo = mini(current_ammo + amount, max_ammo)

func get_upgrade_description() -> String:
	match level:
		1:
			return "Level 2: +50% damage, larger mag"
		2:
			return "Level 3: +50% damage, faster fire rate"
		3:
			return "Level 4: +50% damage, less spread"
		4:
			return "Level 5: +50% damage, piercing shots"
		_:
			return "MAX LEVEL"

func _apply_upgrade() -> void:
	match level:
		2:
			max_ammo = 40
			current_ammo = max_ammo
		3:
			fire_rate = 0.2
		4:
			spread = 0.05
		5:
			spread = 0.0

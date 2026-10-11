extends Weapon
class_name Gun

# Gun evolution: Pistol -> Shotgun -> Minigun. Tier-ups swap the whole
# package (damage, rate, pellets, mag, bullet art); no stat levels.
const TIER_NAMES: Array[String] = ["Pistol", "Shotgun", "Minigun"]
const TIER_KEYS: Array[String] = ["weapon_pistol", "weapon_shotgun", "weapon_minigun"]
const TIER_MAX := 2
const TIER_BULLETS: Array[Texture2D] = [
	preload("res://assets/gfx/weapon/gun/bullet.png"),
	preload("res://assets/gfx/weapon/shotgun/shotgun_bullet.png"),
	preload("res://assets/gfx/weapon/minigun/minigun_bullet.png"),
]
const TIER_BULLET_SCALE: Array[float] = [0.5, 1.5, 0.5]
const TIER_SFX: Array[String] = ["shot", "shotgun_shot", "minigun_loop"]

var tier := 0
var current_ammo: int = 30
var last_shot_time: float = 0.0

@export var bullet_scene: PackedScene

var fire_rate: float = 0.3
var bullet_speed: float = 950.0
var spread: float = 0.1
var pellets: int = 1
var max_ammo: int = 30

# Minigun hold-to-fire state
var is_firing: bool = false

func _init() -> void:
	weapon_name = "Pistol"
	base_damage = 15.0
	max_level = 5
	_apply_tier()

func _apply_tier() -> void:
	match tier:
		0:
			weapon_name = "Pistol"
			base_damage = 15.0
			fire_rate = 0.3
			pellets = 1
			spread = 0.1
			bullet_speed = 950.0
			max_ammo = 30
		1:
			weapon_name = "Shotgun"
			base_damage = 25.0
			fire_rate = 0.9
			pellets = 2
			spread = 0.14
			bullet_speed = 800.0
			max_ammo = 12
		_:
			weapon_name = "Minigun"
			base_damage = 9.0
			fire_rate = 0.05
			pellets = 4
			spread = 0.18
			bullet_speed = 1200.0
			max_ammo = 5000
	current_ammo = max_ammo

func can_tier_up() -> bool:
	return tier < TIER_MAX

func upgrade_tier() -> void:
	if can_tier_up():
		tier += 1
		_apply_tier()

func display_name() -> String:
	return Loc.tr_key(TIER_KEYS[clampi(tier, 0, TIER_MAX)])

func tier_up_name() -> String:
	return Loc.tr_key(TIER_KEYS[clampi(tier + 1, 0, TIER_MAX)])

func tier_up_description() -> String:
	match tier + 1:
		1:
			return Loc.tr_key("gun_desc_shotgun")
		_:
			return Loc.tr_key("gun_desc_minigun")

func start_firing() -> void:
	is_firing = true

func stop_firing() -> void:
	is_firing = false

func attack(spawn_root: Node, player_global_pos: Vector2, mouse_global_pos: Vector2, damage_mult: float, wielder: Node2D = null) -> bool:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < fire_rate:
		return false
	if current_ammo <= 0:
		return false

	last_shot_time = current_time
	current_ammo -= 1

	if mouse_global_pos == player_global_pos:
		return false
	var direction: Vector2 = (mouse_global_pos - player_global_pos).normalized()
	var base_angle: float = direction.angle()

	if bullet_scene == null or not is_instance_valid(spawn_root):
		return false
	var fired := false
	for i in range(pellets):
		var actual_angle: float = base_angle + randf_range(-spread, spread)
		var bullet: Bullet = bullet_scene.instantiate() as Bullet
		if bullet == null:
			continue
		spawn_root.add_child(bullet)
		# Muzzle offset so the bullet never starts inside the shooter.
		var muzzle: Vector2 = player_global_pos + Vector2(cos(actual_angle), sin(actual_angle)) * 26.0
		bullet.global_position = muzzle
		bullet.rotation = actual_angle
		bullet.set_hostile(false)
		bullet.set_bullet_texture(TIER_BULLETS[tier], TIER_BULLET_SCALE[tier])
		bullet.set_bullet_velocity(Vector2(cos(actual_angle), sin(actual_angle)) * bullet_speed)
		bullet.set_damage(get_damage(damage_mult))
		fired = true
	
	# Play tier-specific sound (minigun runs a single loop instead).
	if tier < TIER_MAX and wielder != null and wielder.has_method("get_tree"):
		GameManager.play_sfx(TIER_SFX[tier])
	
	return fired

func add_ammo(amount: int) -> void:
	current_ammo = mini(current_ammo + amount, max_ammo)

func get_upgrade_description() -> String:
	return tier_up_description()

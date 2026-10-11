extends Weapon
class_name Katana

const BLADE_LENGTHS: Array[float] = [56.0, 64.0, 72.0, 80.0, 88.0]
const BLADE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/gfx/weapon/katana/katanal1.png"),
	preload("res://assets/gfx/weapon/katana/katanal2.png"),
	preload("res://assets/gfx/weapon/katana/katanal3.png"),
	preload("res://assets/gfx/weapon/katana/katanal4.png"),
	preload("res://assets/gfx/weapon/katana/katanal5.png"),
]

@export var slash_range: float = 56.0
@export var slash_angle: float = 90.0
@export var cooldown: float = 0.5
@export var slash_scene: PackedScene

var last_attack_time: float = 0.0

func _init() -> void:
	weapon_name = "Katana"
	base_damage = 25.0
	max_level = 5
	slash_range = BLADE_LENGTHS[0]

func get_blade_texture() -> Texture2D:
	return BLADE_TEXTURES[clampi(level - 1, 0, BLADE_TEXTURES.size() - 1)]

func attack(spawn_root: Node, player_global_pos: Vector2, mouse_global_pos: Vector2, damage_mult: float, wielder: Node2D = null) -> bool:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time < cooldown:
		return false
	last_attack_time = current_time

	if mouse_global_pos == player_global_pos:
		return false
	var direction: Vector2 = (mouse_global_pos - player_global_pos).normalized()
	var angle: float = direction.angle()

	if slash_scene and is_instance_valid(spawn_root):
		var slash: SlashEffect = slash_scene.instantiate() as SlashEffect
		if slash == null:
			return false
		spawn_root.add_child(slash)
		slash.global_position = player_global_pos
		# Local -Y is the blade direction, so rotate +90deg to face the mouse.
		slash.rotation = angle + PI / 2.0
		slash.setup(get_blade_texture(), slash_range, get_damage(damage_mult), level, wielder)
		return true
	return false

func get_upgrade_description() -> String:
	match level:
		1:
			return "Blade 64px, faster swing"
		2:
			return "Blade 72px, faster swing"
		3:
			return "Blade 80px, longer reach"
		4:
			return "Blade 88px, fastest swing"
		_:
			return "MAX LEVEL"

func _apply_upgrade() -> void:
	slash_range = BLADE_LENGTHS[clampi(level - 1, 0, BLADE_LENGTHS.size() - 1)]
	match level:
		2:
			slash_angle = 120.0
			cooldown = 0.45
		3:
			cooldown = 0.38
		4:
			cooldown = 0.34
		5:
			cooldown = 0.3
			slash_angle = 180.0

extends Resource
class_name Weapon

@export var weapon_name: String = "Weapon"
@export var base_damage: float = 10.0
@export var level: int = 1
@export var max_level: int = 5

func attack(_spawn_root: Node, _player_global_pos: Vector2, _mouse_global_pos: Vector2, _damage_mult: float, _wielder: Node2D = null) -> void:
	pass

func get_upgrade_description() -> String:
	return ""

func get_damage(damage_mult: float) -> float:
	return base_damage * float(level) * damage_mult

func can_upgrade() -> bool:
	return level < max_level

func upgrade() -> void:
	if can_upgrade():
		level += 1
		_apply_upgrade()

func _apply_upgrade() -> void:
	pass

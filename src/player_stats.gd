extends Resource
class_name PlayerStats

@export var max_health: float = 100.0
@export var speed: float = 250.0
@export var damage_multiplier: float = 1.0
@export var xp: int = 0
@export var xp_to_next_level: int = 100
@export var stat_points: int = 0

var current_health: float = 100.0

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)

func take_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
	if current_health <= 0.0:
		die()

func add_xp(amount: int) -> bool:
	xp += amount
	var leveled_up = false
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		xp_to_next_level = int(xp_to_next_level * 1.5)
		stat_points += 1
		leveled_up = true
	return leveled_up

func upgrade_health() -> void:
	if stat_points > 0:
		max_health += 20
		current_health = max_health
		stat_points -= 1

func grow_max_hp(amount: float = 25.0) -> void:
	max_health += amount
	current_health = max_health

func upgrade_speed() -> void:
	if stat_points > 0:
		speed += 30
		stat_points -= 1

func upgrade_damage() -> void:
	if stat_points > 0:
		damage_multiplier += 0.2
		stat_points -= 1

func die() -> void:
	print("Player died!")
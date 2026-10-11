extends GhostBehavior
class_name BlinkyBehavior

@export var max_bonus: float = 0.6

func get_target(enemy) -> Vector2:
	if enemy == null or enemy.player == null or not is_instance_valid(enemy.player):
		return enemy.global_position if enemy != null else Vector2.ZERO
	return enemy.player.global_position

func get_speed_multiplier(enemy) -> float:
	if enemy == null or not enemy.is_inside_tree():
		return 1.0
	var wm: Node = enemy.get_tree().get_first_node_in_group("wave_manager")
	if wm == null or not wm.has_method("get_enemies_left"):
		return 1.0
	var left: int = int(wm.call("get_enemies_left"))
	var quota: int = _initial_quota(wm)
	if quota <= 0:
		return 1.0
	var ratio: float = clampf(float(left) / float(quota), 0.0, 1.0)
	return 1.0 + (1.0 - ratio) * max_bonus

func _initial_quota(wm: Node) -> int:
	if wm == null:
		return 0
	var wave: int = int(wm.get("current_wave"))
	if wave == 5:
		return 1
	var base_q: int = int(wm.get("base_enemies_per_wave"))
	var step: int = int(wm.get("enemy_increase_per_wave"))
	return base_q + (wave - 1) * step

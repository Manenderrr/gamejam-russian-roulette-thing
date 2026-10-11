extends RefCounted
class_name GhostBehavior

const TILE_PX: float = 16.0

func get_target(enemy) -> Vector2:
	if enemy == null or enemy.player == null or not is_instance_valid(enemy.player):
		return enemy.global_position if enemy != null else Vector2.ZERO
	return enemy.player.global_position

func get_speed_multiplier(_enemy) -> float:
	return 1.0

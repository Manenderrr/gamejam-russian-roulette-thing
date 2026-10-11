extends GhostBehavior
class_name PinkyBehavior

const AHEAD_TILES: float = 4.0

func get_target(enemy) -> Vector2:
	if enemy == null or enemy.player == null or not is_instance_valid(enemy.player):
		return enemy.global_position if enemy != null else Vector2.ZERO
	var dir: Vector2 = enemy.get_player_move_dir()
	if dir == Vector2.ZERO:
		return enemy.player.global_position
	return enemy.player.global_position + dir * (AHEAD_TILES * TILE_PX)

extends GhostBehavior
class_name InkyBehavior

const AHEAD_TILES: float = 2.0

func get_target(enemy) -> Vector2:
	if enemy == null or enemy.player == null or not is_instance_valid(enemy.player):
		return enemy.global_position if enemy != null else Vector2.ZERO
	var dir: Vector2 = enemy.get_player_move_dir()
	var pivot: Vector2 = enemy.player.global_position
	if dir != Vector2.ZERO:
		pivot += dir * (AHEAD_TILES * TILE_PX)
	var blinky_pos: Vector2 = enemy.get_blinky_position()
	if blinky_pos == Vector2.INF:
		return pivot
	return pivot + (pivot - blinky_pos)

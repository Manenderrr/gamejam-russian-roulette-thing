extends GhostBehavior
class_name ClydeBehavior

const SCATTER_TILES: float = 8.0

func get_target(enemy) -> Vector2:
	if enemy == null or enemy.player == null or not is_instance_valid(enemy.player):
		return enemy.global_position if enemy != null else Vector2.ZERO
	var dist_px: float = enemy.global_position.distance_to(enemy.player.global_position)
	if dist_px > SCATTER_TILES * TILE_PX:
		return enemy.player.global_position
	return enemy.get_retreat_corner()

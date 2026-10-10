extends Camera2D
## Halves the distance to the target roughly every second.

@export var target: Node2D

func _process(delta: float) -> void:
	if target:
		var target_pos := target.global_position
		var difference := target_pos - global_position
		var tick_movement := delta * 2
		if tick_movement > 1:
			global_position = target_pos 
		else:
			global_translate(difference * delta * 2)

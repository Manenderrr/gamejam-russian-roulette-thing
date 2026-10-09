extends Camera2D

@export var target: Node2D

## Camera movement speed in seconds.
@export var movement_speed: float = 750

func _process(delta: float) -> void:
	if target:
		var difference := target.global_position - global_position
		if difference.length() > 10: 
			global_translate(difference.normalized() * delta * movement_speed)

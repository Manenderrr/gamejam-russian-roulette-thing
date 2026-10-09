extends Sprite2D

## Walking speed in pixels per second.
@export var walking_speed: float = 1000

func _process(delta: float) -> void:
	translate(Input.get_vector("go_left", "go_right", "go_up", "go_down").normalized() * delta * walking_speed)
	pass

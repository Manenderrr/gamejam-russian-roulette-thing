extends CharacterBody2D

## Walking speed in pixels per second.
@export var walking_speed: float = 250
@export var melee_collision: ShapeCast2D

func _physics_process(delta: float) -> void:
	var movement_velocity := Input.get_vector("go_left", "go_right", "go_up", "go_down") * delta * walking_speed
	var collision := move_and_collide(movement_velocity)
	if collision:
		move_and_collide(movement_velocity.slide(collision.get_normal()))
	rotate(get_local_mouse_position().angle() + PI / 2)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("melee"):
		melee()

func melee() -> void:
	if not melee_collision:
		return
	print("melee")
	melee_collision.force_shapecast_update()
	for i in melee_collision.get_collision_count():
		var obj := melee_collision.get_collider(i)
		print(obj)


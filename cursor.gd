extends Node2D
## Script for a software cursor.
## The game currently uses a hardware one so this is not needed, but might be in the future.

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		global_position = get_canvas_transform().affine_inverse() * event.position

func _enter_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

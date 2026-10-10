extends Control

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("stop_battle_music"):
		gm.call("stop_battle_music")
	var play_button: Button = $Panel/VBoxContainer/PlayButton
	var exit_button: Button = $Panel/VBoxContainer/ExitButton
	
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_play_pressed() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("start_new_game"):
		gm.call("start_new_game")
	else:
		get_tree().change_scene_to_file("res://src/level/level.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
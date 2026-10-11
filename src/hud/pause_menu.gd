extends CanvasLayer

@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitToMenuButton

func _ready() -> void:
	# UI must keep processing input while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	visible = false

func show_pause() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.play_sfx("window")

func _on_continue_pressed() -> void:
	GameManager.play_sfx("select")
	visible = false
	get_tree().paused = false
	# This game aims with a visible cursor: captured mode would hide it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_exit_pressed() -> void:
	GameManager.play_sfx("select")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/hud/main_menu.tscn")

extends CanvasLayer

@onready var retry_button: Button = $Panel/VBoxContainer/RetryButton
@onready var menu_button: Button = $Panel/VBoxContainer/MenuButton

func _ready() -> void:
	# Buttons must stay clickable while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	visible = false

func show_death() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.play_sfx("window")

func _on_retry_pressed() -> void:
	GameManager.play_sfx("select")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/level/level.tscn")

func _on_menu_pressed() -> void:
	GameManager.play_sfx("select")
	get_tree().paused = false
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("stop_battle_music"):
		gm.call("stop_battle_music")
	get_tree().change_scene_to_file("res://src/hud/main_menu.tscn")

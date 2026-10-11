extends CanvasLayer

@onready var title: Label = $Panel/VBoxContainer/Title
@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitToMenuButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var settings_screen: CanvasLayer = $SettingsScreen

func _ready() -> void:
	# UI must keep processing input while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	Loc.language_changed.connect(refresh_texts)
	refresh_texts()
	visible = false

func refresh_texts() -> void:
	title.text = Loc.tr_key("pause_title")
	continue_button.text = Loc.tr_key("pause_continue")
	exit_button.text = Loc.tr_key("pause_exit")
	settings_button.text = Loc.tr_key("pause_settings")

func show_pause() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.stop_minigun_loop()
	GameManager.play_sfx("window")

func _on_settings_pressed() -> void:
	settings_screen.call("show_settings")

func _on_continue_pressed() -> void:
	GameManager.play_sfx("select")
	settings_screen.visible = false
	visible = false
	get_tree().paused = false
	# This game aims with a visible cursor: captured mode would hide it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_exit_pressed() -> void:
	GameManager.play_sfx("select")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/hud/main_menu.tscn")

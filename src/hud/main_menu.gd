extends Control

@export var level_scene: PackedScene

@onready var play_button: Button = $Panel/VBoxContainer/PlayButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var about_button: Button = $Panel/VBoxContainer/AboutButton
@onready var settings_screen: CanvasLayer = $SettingsScreen
@onready var about_screen: CanvasLayer = $AboutScreen
@onready var menu_music: AudioStreamPlayer = $Music

func _ready() -> void:
	assert(level_scene, "level_scene is not set")

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("stop_battle_music"):
		gm.call("stop_battle_music")
	if gm != null and gm.has_method("stop_special_music"):
		gm.call("stop_special_music")
	settings_button.pressed.connect(_on_settings_pressed)
	about_button.pressed.connect(_on_about_pressed)
	about_screen.connect("closed", _on_about_closed)
	Loc.language_changed.connect(refresh_texts)
	refresh_texts()

func refresh_texts() -> void:
	play_button.text = Loc.tr_key("menu_play")
	exit_button.text = Loc.tr_key("menu_exit")
	settings_button.text = Loc.tr_key("menu_settings")
	about_button.text = Loc.tr_key("menu_about")

func _on_settings_pressed() -> void:
	settings_screen.call("show_settings")

func _on_about_pressed() -> void:
	if menu_music != null and menu_music.playing:
		menu_music.stop()
	about_screen.call("show_about")

func _on_about_closed() -> void:
	if menu_music != null and not menu_music.playing:
		menu_music.play()

func begin_game() -> void:
	assert(level_scene, "level_scene is not set")
	GameManager.play_sfx("select")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("play_intro_cutscene"):
		gm.call("play_intro_cutscene")
	elif gm != null and gm.has_method("start_new_game"):
		gm.call("start_new_game")
	else:
		get_tree().change_scene_to_packed(level_scene)

func quit_game() -> void:
	get_tree().quit()

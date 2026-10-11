extends Control

@export var level_scene: PackedScene

func _ready() -> void:
	assert(level_scene, "level_scene is not set")

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("stop_battle_music"):
		gm.call("stop_battle_music")

func begin_game() -> void:
	assert(level_scene, "level_scene is not set")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("start_new_game"):
		gm.call("start_new_game")
	else:
		get_tree().change_scene_to_packed(level_scene)

func quit_game() -> void:
	get_tree().quit()

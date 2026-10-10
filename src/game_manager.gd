extends Node

# Owns the battle music so floor transitions, pauses and hitches can
# never cut it. Menu music lives in the menu scene and stops on its own
# when the level loads.

var current_wave: int = 1
var battle_music: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle_music = AudioStreamPlayer.new()
	battle_music.name = "BattleMusic"
	battle_music.stream = load("res://assets/audio/music/gamebattle.ogg") as AudioStream
	battle_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(battle_music)

func start_new_game() -> void:
	current_wave = 1
	play_battle_music()
	get_tree().change_scene_to_file("res://src/level/level.tscn")

func play_battle_music() -> void:
	if battle_music != null and not battle_music.playing:
		battle_music.play()

func stop_battle_music() -> void:
	if battle_music != null and battle_music.playing:
		battle_music.stop()

extends Node

# Owns the battle music so floor transitions, pauses and hitches can
# never cut it. Menu music lives in the menu scene and stops on its own
# when the level loads.

var current_wave: int = 1
var battle_music: AudioStreamPlayer = null

const SFX: Dictionary = {
	"sweep": preload("res://assets/audio/sfx/katana_sweep.ogg"),
	"shot": preload("res://assets/audio/sfx/pistol_shot.ogg"),
	"reload": preload("res://assets/audio/sfx/pistol_reload.ogg"),
	"hit": preload("res://assets/audio/sfx/damage_enemy.ogg"),
	"take": preload("res://assets/audio/sfx/xp_take.ogg"),
	"window": preload("res://assets/audio/sfx/window_appear.ogg"),
	"select": preload("res://assets/audio/sfx/menu_select.ogg"),
}
const SFX_POOL := 8
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_next := 0

const BATTLE_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/gamebattle1.ogg"),
	preload("res://assets/audio/music/02 - Lucifer.ogg"),
	preload("res://assets/audio/music/03 - drain.ogg"),
	preload("res://assets/audio/music/04 - AC41-00050A.ogg"),
	preload("res://assets/audio/music/04 - ayounemd.ogg"),
	preload("res://assets/audio/music/05 - betrFlonM.ogg"),
	preload("res://assets/audio/music/07 - goresinn.ogg"),
	preload("res://assets/audio/music/08 - unnrR35sT.ogg"),
	preload("res://assets/audio/music/10 - D0nor.ogg"),
	preload("res://assets/audio/music/11 - Poignant.ogg"),
]
var battle_order: Array[int] = []
var battle_pos := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle_music = AudioStreamPlayer.new()
	battle_music.name = "BattleMusic"
	battle_music.process_mode = Node.PROCESS_MODE_ALWAYS
	battle_music.finished.connect(_on_battle_track_finished)
	add_child(battle_music)
	for i in range(SFX_POOL):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_players.append(p)

func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not SFX.has(sfx_name) or sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	p.stream = SFX[sfx_name]
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()

func start_new_game() -> void:
	current_wave = 1
	play_battle_music()
	get_tree().change_scene_to_file("res://src/level/level.tscn")

func play_battle_music() -> void:
	if battle_music != null and not battle_music.playing:
		if battle_order.is_empty():
			_shuffle_battle(-1)
		battle_music.stream = BATTLE_TRACKS[battle_order[battle_pos]]
		battle_music.play()

func _on_battle_track_finished() -> void:
	if BATTLE_TRACKS.is_empty():
		return
	var last: int = battle_order[battle_pos] if not battle_order.is_empty() else -1
	battle_pos += 1
	if battle_pos >= battle_order.size():
		_shuffle_battle(last)
		battle_pos = 0
	battle_music.stream = BATTLE_TRACKS[battle_order[battle_pos]]
	battle_music.play()

func _shuffle_battle(first_avoid: int) -> void:
	battle_order.clear()
	for i in range(BATTLE_TRACKS.size()):
		battle_order.append(i)
	battle_order.shuffle()
	if BATTLE_TRACKS.size() > 1 and battle_order[0] == first_avoid:
		battle_order[0] = battle_order[1]
		battle_order[1] = first_avoid

func stop_battle_music() -> void:
	if battle_music != null and battle_music.playing:
		battle_music.stop()

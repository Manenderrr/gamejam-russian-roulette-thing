extends Node

# Owns the battle music so floor transitions, pauses and hitches can
# never cut it. Menu music lives in the menu scene and stops on its own
# when the level loads.

var current_wave: int = 1
var battle_music: AudioStreamPlayer = null
var special_music: AudioStreamPlayer = null
var minigun_loop_player: AudioStreamPlayer = null
var came_from_intro: bool = false
# Last window size seen while focused. Restored if the OS shrinks the
# window behind the game's back (e.g. fitting it onto a smaller monitor).
var _good_size: Vector2i = Vector2i(1280, 720)
var _focused: bool = true
var _last_screen: int = -1


const SFX: Dictionary = {
	"sweep": preload("res://assets/audio/sfx/katana_sweep.ogg"),
	"shot": preload("res://assets/audio/sfx/pistol_shot.ogg"),
	"reload": preload("res://assets/audio/sfx/pistol_reload.ogg"),
	"hit": preload("res://assets/audio/sfx/damage_enemy.ogg"),
	"take": preload("res://assets/audio/sfx/xp_take.ogg"),
	"window": preload("res://assets/audio/sfx/window_appear.ogg"),
	"select": preload("res://assets/audio/sfx/menu_select.ogg"),
	"shotgun_shot": preload("res://assets/audio/sfx/shotgun_shot.ogg"),
	"shotgun_pump": preload("res://assets/audio/sfx/shotgun_pump.ogg"),
	"minigun_loop": preload("res://assets/audio/sfx/minigun_shots_loop.ogg"),
}
const SFX_POOL := 8
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_next := 0

const INTRO_TRACK: AudioStream = preload("res://assets/audio/music/start.ogg")
const OUTRO_TRACK: AudioStream = preload("res://assets/audio/music/end.ogg")
const ABOUT_TRACK: AudioStream = preload("res://assets/audio/music/about.ogg")

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

const CODE_VERSION := "pair67-probe-manualscale-v8"

var outro_watchdog: int = 0
var _watch_frames: int = 0

func arm_outro_watchdog() -> void:
	outro_watchdog = 12
	_watch_frames = 0

func _process(_delta: float) -> void:
	# Runs even while the tree is paused (autoload is ALWAYS), so these
	# lines prove whether frames advance at all during the finale.
	if outro_watchdog <= 0:
		return
	_watch_frames += 1
	if _watch_frames >= 300:
		_watch_frames = 0
		outro_watchdog -= 1
		print("[outro] watchdog alive, tree.paused=", get_tree().paused)

func _ready() -> void:
	print("Katana-Punk core ", CODE_VERSION)
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle_music = AudioStreamPlayer.new()
	battle_music.name = "BattleMusic"
	battle_music.bus = &"Music"
	battle_music.process_mode = Node.PROCESS_MODE_ALWAYS
	battle_music.finished.connect(_on_battle_track_finished)
	add_child(battle_music)
	special_music = AudioStreamPlayer.new()
	special_music.name = "SpecialMusic"
	special_music.bus = &"Music"
	special_music.process_mode = Node.PROCESS_MODE_ALWAYS
	special_music.finished.connect(_on_special_track_finished)
	add_child(special_music)
	for i in range(SFX_POOL):
		var p := AudioStreamPlayer.new()
		p.bus = &"Main"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_players.append(p)
	minigun_loop_player = AudioStreamPlayer.new()
	minigun_loop_player.name = "MinigunLoop"
	minigun_loop_player.bus = &"Main"
	minigun_loop_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(minigun_loop_player)
	var vw: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var vh: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	DisplayServer.window_set_min_size(Vector2i(vw, vh))
	_good_size = DisplayServer.window_get_size()
	if _good_size.x <= 0 or _good_size.y <= 0:
		_good_size = Vector2i(vw, vh)
	_last_screen = DisplayServer.window_get_current_screen()
	get_tree().root.size_changed.connect(_on_root_size_changed)
	get_tree().root.focus_entered.connect(_on_window_focus_entered)
	get_tree().root.focus_exited.connect(_on_window_focus_exited)

func _on_root_size_changed() -> void:
	# Genuine resizes happen while focused and become the new baseline.
	# Shrinks applied while unfocused are ignored so they can't poison it.
	if _focused:
		var cur: Vector2i = DisplayServer.window_get_size()
		if cur.x > 0 and cur.y > 0:
			_good_size = cur

func _on_window_focus_entered() -> void:
	_focused = true
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var cur: Vector2i = DisplayServer.window_get_size()
	if cur.x <= 0 or cur.y <= 0:
		return
	if cur.x < _good_size.x or cur.y < _good_size.y:
		DisplayServer.window_set_size(_good_size)
		print("Katana-Punk window restored to ", _good_size)
		return
	var scr: int = DisplayServer.window_get_current_screen()
	if scr != _last_screen:
		_last_screen = scr
		# Same-size poke: geometry never changes, but the driver
		# renegotiates DPI and swapchain after a monitor switch.
		DisplayServer.window_set_size(cur)

func _on_window_focus_exited() -> void:
	_focused = false

func start_minigun_loop() -> void:
	if minigun_loop_player == null:
		return
	if not minigun_loop_player.playing:
		minigun_loop_player.stream = SFX["minigun_loop"]
		minigun_loop_player.play()

func stop_minigun_loop() -> void:
	if minigun_loop_player != null and minigun_loop_player.playing:
		minigun_loop_player.stop()

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

func play_intro_cutscene() -> void:
	current_wave = 1
	came_from_intro = true
	stop_battle_music()
	get_tree().change_scene_to_file("res://src/cutscene/intro_cutscene.tscn")

func consume_intro_flag() -> bool:
	var c: bool = came_from_intro
	came_from_intro = false
	return c

func play_outro_cutscene() -> void:
	stop_battle_music()
	get_tree().change_scene_to_file("res://src/cutscene/outro_cutscene.tscn")

func _play_special(track: AudioStream) -> void:
	stop_battle_music()
	if special_music == null:
		return
	special_music.stream = track
	special_music.play()

func play_intro_music() -> void:
	_play_special(INTRO_TRACK)

func play_outro_music() -> void:
	_play_special(OUTRO_TRACK)

func play_about_music() -> void:
	_play_special(ABOUT_TRACK)

func stop_special_music() -> void:
	if special_music != null and special_music.playing:
		special_music.stop()

func _on_special_track_finished() -> void:
	if special_music != null and special_music.stream != null:
		special_music.play()

func play_battle_music() -> void:
	stop_special_music()
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

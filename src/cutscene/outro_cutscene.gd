extends Node2D
class_name OutroCutscene

const SKIES: Array[Texture2D] = [
	preload("res://assets/gfx/cutscenes/outro/sky1.png"),
	preload("res://assets/gfx/cutscenes/outro/sky2.png"),
	preload("res://assets/gfx/cutscenes/outro/sky3.png"),
]
const MOON: Texture2D = preload("res://assets/gfx/cutscenes/outro/moon.png")
const GRASS: Texture2D = preload("res://assets/gfx/cutscenes/outro/grass1.png")
const GRASS2: Texture2D = preload("res://assets/gfx/cutscenes/outro/grass2.png")
const ROAD: Texture2D = preload("res://assets/gfx/cutscenes/outro/road1.png")
const SKY_CYCLE_TIME: float = 1.5
const MOON_H: float = 96.0
const TOWER: Texture2D = preload("res://assets/gfx/cutscenes/outro/evil_corp_tower_1.png")
const BOOM: Texture2D = preload("res://assets/gfx/cutscenes/outro/boom_0.png")
const BROKEN1: Texture2D = preload("res://assets/gfx/cutscenes/outro/evil_corp_tower_broken1.png")
const BROKEN2: Texture2D = preload("res://assets/gfx/cutscenes/outro/evil_corp_tower_broken2.png")
const PARACHUTE: Texture2D = preload("res://assets/gfx/cutscenes/outro/player_parachute.png")
const END_TRACK: AudioStream = preload("res://assets/audio/music/end.ogg")
const MAIN_MENU: String = "res://src/hud/main_menu.tscn"
const TILE_SCALE: float = 2.0
const GROUND_H: float = 192.0
const TOWER_SCALE: float = 3.5
const PLAYER_H: float = 96.0
const FADE_TIME: float = 2.0
const DESCENT_TIME: float = 5.0
const BOOM_TIME: float = 1.0
const HOLD_TIME: float = 20.0

var _tower: Sprite2D = null
var _jumper: Sprite2D = null
var _fade: ColorRect = null
var _sky_tiles: Array[Sprite2D] = []
var _sky_t: float = 0.0

var _leaving: bool = false

func _ready() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("stop_battle_music"):
		gm.call("stop_battle_music")
	if gm != null and gm.has_method("stop_special_music"):
		gm.call("stop_special_music")
	_build()
	_play_music()
	_play()

var _elapsed: float = 0.0
var _max_t: float = 35.0

func _play_music() -> void:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.stream = END_TRACK
	p.finished.connect(_leave_to_menu)
	add_child(p)
	if END_TRACK != null:
		_max_t = END_TRACK.get_length() + 5.0
		p.play()

func _leave_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(MAIN_MENU)

func _build() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var cam := Camera2D.new()
	cam.position = vs * 0.5
	cam.enabled = true
	add_child(cam)
	_add_sky(vs)
	_add_moon(vs)
	_add_ground(vs)
	_add_tower(vs)
	_add_jumper(vs)
	_add_fade()

func _pix() -> int:
	return CanvasItem.TEXTURE_FILTER_NEAREST

func _add_sky(vs: Vector2) -> void:
	_sky_tiles.clear()
	var layer := Node2D.new()
	layer.z_index = -10
	add_child(layer)
	var tex: Texture2D = SKIES[0]
	var w: float = tex.get_size().x * TILE_SCALE
	var h: float = tex.get_size().y * TILE_SCALE
	var cols: int = int(ceil(vs.x / w)) + 1
	var rows: int = int(ceil(vs.y / h)) + 1
	for cx in range(cols):
		for ry in range(rows):
			var s := Sprite2D.new()
			s.texture = SKIES[randi() % SKIES.size()]
			s.texture_filter = _pix()
			s.scale = Vector2(TILE_SCALE, TILE_SCALE)
			s.position = Vector2(cx * w + w * 0.5, ry * h + h * 0.5)
			layer.add_child(s)
			_sky_tiles.append(s)
	_sky_t = 0.0

func _twinkle_sky() -> void:
	for i in range(mini(14, _sky_tiles.size())):
		var s: Sprite2D = _sky_tiles[randi() % _sky_tiles.size()]
		s.texture = SKIES[randi() % SKIES.size()]

func _add_moon(vs: Vector2) -> void:
	var moon := Sprite2D.new()
	moon.texture = MOON
	moon.texture_filter = _pix()
	var sc: float = MOON_H / MOON.get_size().y
	moon.scale = Vector2(sc, sc)
	moon.position = Vector2(vs.x - 150.0, 120.0)
	moon.z_index = -9
	add_child(moon)
	var drift := create_tween()
	drift.set_loops()
	drift.tween_property(moon, "position:x", moon.position.x - 48.0, 6.0)
	drift.tween_property(moon, "position:x", moon.position.x, 6.0)

func _tile_row(tex: Texture2D, y: float, vs: Vector2, z: int) -> void:
	var w: float = tex.get_size().x * TILE_SCALE
	var cols: int = int(ceil(vs.x / w)) + 1
	for cx in range(cols):
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = _pix()
		s.scale = Vector2(TILE_SCALE, TILE_SCALE)
		s.position = Vector2(cx * w + w * 0.5, y)
		s.z_index = z
		add_child(s)

func _add_ground(vs: Vector2) -> void:
	var gh: float = GRASS.get_size().y * TILE_SCALE
	var rows: int = int(ceil(GROUND_H / gh))
	for ry in range(rows):
		_tile_row(GRASS if ry % 2 == 0 else GRASS2, vs.y - GROUND_H + ry * gh + gh * 0.5, vs, 0)
	_tile_row(ROAD, vs.y - GROUND_H + 32.0, vs, 1)
	_tile_row(ROAD, vs.y - GROUND_H + 112.0, vs, 1)

func _tower_center(vs: Vector2) -> Vector2:
	var th: float = TOWER.get_size().y * TOWER_SCALE
	return Vector2(vs.x * 0.5, vs.y - GROUND_H - th * 0.5 + 8.0)

func _ground_pos(vs: Vector2) -> Vector2:
	return Vector2(vs.x * 0.5, vs.y - GROUND_H - 4.0)

func _add_tower(vs: Vector2) -> void:
	_tower = Sprite2D.new()
	_tower.texture = TOWER
	_tower.texture_filter = _pix()
	_tower.scale = Vector2(TOWER_SCALE, TOWER_SCALE)
	_tower.position = _tower_center(vs)
	_tower.z_index = 2
	add_child(_tower)

func _add_jumper(vs: Vector2) -> void:
	_jumper = Sprite2D.new()
	_jumper.texture = PARACHUTE
	_jumper.texture_filter = _pix()
	var sc: float = PLAYER_H / PARACHUTE.get_size().y
	_jumper.scale = Vector2(sc, sc)
	var th: float = TOWER.get_size().y * TOWER_SCALE
	var tower_top: float = vs.y - GROUND_H - th + 8.0
	_jumper.position = Vector2(vs.x * 0.5, tower_top + 48.0)
	_jumper.z_index = 5
	add_child(_jumper)

func _add_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

func _process(delta: float) -> void:
	if not _sky_tiles.is_empty():
		_sky_t += delta
		if _sky_t >= SKY_CYCLE_TIME:
			_sky_t = 0.0
			_twinkle_sky()
	if _leaving:
		return
	_elapsed += delta
	if _elapsed >= _max_t:
		_leave_to_menu()

func _play() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await tw.finished
	var land: Vector2 = _ground_pos(get_viewport_rect().size)
	var fall := create_tween()
	fall.tween_property(_jumper, "position", land, DESCENT_TIME)
	await fall.finished
	await get_tree().create_timer(BOOM_TIME).timeout
	_tower.texture = BOOM
	await get_tree().create_timer(BOOM_TIME).timeout
	_tower.texture = BROKEN1
	await get_tree().create_timer(BOOM_TIME).timeout
	_tower.texture = BROKEN2
	await get_tree().create_timer(HOLD_TIME).timeout
	_leave_to_menu()

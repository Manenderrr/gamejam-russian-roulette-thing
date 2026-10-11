extends Node2D
class_name IntroCutscene

const SKIES: Array[Texture2D] = [
	preload("res://assets/gfx/cutscenes/intro/sky1.png"),
	preload("res://assets/gfx/cutscenes/intro/sky2.png"),
	preload("res://assets/gfx/cutscenes/intro/sky3.png"),
]
const MOON: Texture2D = preload("res://assets/gfx/cutscenes/intro/moon.png")
const GRASS: Texture2D = preload("res://assets/gfx/cutscenes/intro/grass1.png")
const GRASS2: Texture2D = preload("res://assets/gfx/cutscenes/intro/grass2.png")
const ROAD: Texture2D = preload("res://assets/gfx/cutscenes/intro/road1.png")
const SKY_CYCLE_TIME: float = 1.5
const MOON_H: float = 96.0
const TOWER: Texture2D = preload("res://assets/gfx/cutscenes/intro/evil_corp_tower_1.png")
const PLAYER_IDLE: Texture2D = preload("res://assets/gfx/player/idle.webp")
const PLAYER_WALK: Texture2D = preload("res://assets/gfx/player/walk_1.webp")
const LEVEL_SCENE: String = "res://src/level/level.tscn"
const TILE_SCALE: float = 2.0
const GROUND_H: float = 192.0
const TOWER_SCALE: float = 3.5
const PLAYER_H: float = 96.0
const WALK_TIME: float = 3.2
const FADE_TIME: float = 0.8
const SKIP_FADE_TIME: float = 0.25
const WALK_ANIM_TICK: float = 0.16

var _player: Sprite2D = null
var _fade: ColorRect = null
var _sky_tiles: Array[Sprite2D] = []
var _sky_t: float = 0.0
var _walk_tween: Tween = null
var _walk_t: float = 0.0
var _walk_frame: bool = false
var _walking: bool = false
var _finishing: bool = false

func _ready() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("play_intro_music"):
		gm.call("play_intro_music")
	_build()
	_play()

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
	_add_player(vs)
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

func _door_pos(vs: Vector2) -> Vector2:
	return Vector2(vs.x * 0.5, vs.y - GROUND_H - 4.0)

func _add_tower(vs: Vector2) -> void:
	var tower := Sprite2D.new()
	tower.texture = TOWER
	tower.texture_filter = _pix()
	tower.scale = Vector2(TOWER_SCALE, TOWER_SCALE)
	var th: float = TOWER.get_size().y * TOWER_SCALE
	tower.position = Vector2(vs.x * 0.5, vs.y - GROUND_H - th * 0.5 + 8.0)
	tower.z_index = 2
	add_child(tower)

func _add_player(vs: Vector2) -> void:
	_player = Sprite2D.new()
	_player.texture = PLAYER_IDLE
	_player.texture_filter = _pix()
	var sc: float = PLAYER_H / PLAYER_IDLE.get_size().y
	_player.scale = Vector2(sc, sc)
	_player.position = Vector2(vs.x * 0.5, vs.y - 32.0)
	_player.z_index = 5
	add_child(_player)

func _add_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

func _play() -> void:
	_walking = true
	_walk_tween = create_tween()
	_walk_tween.tween_property(_player, "position", _door_pos(get_viewport_rect().size), WALK_TIME)
	_walk_tween.tween_callback(_finish.bind(false))

func _process(delta: float) -> void:
	if not _sky_tiles.is_empty() and not _finishing:
		_sky_t += delta
		if _sky_t >= SKY_CYCLE_TIME:
			_sky_t = 0.0
			_twinkle_sky()
	if not _walking or _player == null:
		return
	_walk_t += delta
	if _walk_t >= WALK_ANIM_TICK:
		_walk_t = 0.0
		_walk_frame = not _walk_frame
		_player.texture = PLAYER_WALK if _walk_frame else PLAYER_IDLE

func _unhandled_input(event: InputEvent) -> void:
	if _finishing:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_finish(true)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish(true)

func _finish(fast: bool) -> void:
	if _finishing:
		return
	_finishing = true
	_walking = false
	if _player != null:
		_player.texture = PLAYER_IDLE
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, SKIP_FADE_TIME if fast else FADE_TIME)
	await tw.finished
	get_tree().change_scene_to_file(LEVEL_SCENE)

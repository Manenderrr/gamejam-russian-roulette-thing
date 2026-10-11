extends Node

signal language_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const LOC_DIR: String = "res://assets/loc/"
const SUPPORTED: Array[String] = ["en", "ru"]
const DEFAULT_LANG: String = "en"
const DEFAULT_VOLUME: float = 67.0

var language: String = DEFAULT_LANG
var _tables: Dictionary = {}
var _music_volume: float = DEFAULT_VOLUME
var _sfx_volume: float = DEFAULT_VOLUME

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for code in SUPPORTED:
		_tables[code] = _load_xml(LOC_DIR + code + ".xml")
	_load_settings()
	_apply_volumes()

func set_language(code: String) -> void:
	if not SUPPORTED.has(code) or code == language:
		return
	language = code
	_save_settings()
	language_changed.emit()

func get_language() -> String:
	return language

func tr_key(string_id: String, args: Array = []) -> String:
	var table: Dictionary = _tables.get(language, {})
	var text: String = str(table.get(string_id, string_id))
	if args.is_empty():
		return text
	return text % args

func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 200.0)
	_apply_volumes()
	_save_settings()

func get_music_volume() -> float:
	return _music_volume

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 200.0)
	_apply_volumes()
	_save_settings()

func get_sfx_volume() -> float:
	return _sfx_volume

func _apply_volumes() -> void:
	var music_id: int = AudioServer.get_bus_index(&"Music")
	if music_id >= 0:
		AudioServer.set_bus_volume_linear(music_id, _music_volume / 100.0)
	var sfx_id: int = AudioServer.get_bus_index(&"Main")
	if sfx_id >= 0:
		AudioServer.set_bus_volume_linear(sfx_id, _sfx_volume / 100.0)

func _load_xml(path: String) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	var parser := XMLParser.new()
	if parser.open_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return out
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "string" or parser.is_empty():
			continue
		var string_id: String = parser.get_named_attribute_value("id")
		if string_id.is_empty():
			continue
		var text: String = ""
		while parser.read() == OK:
			var t: XMLParser.NodeType = parser.get_node_type()
			if t == XMLParser.NODE_TEXT:
				text += parser.get_node_data()
			elif t == XMLParser.NODE_ELEMENT_END:
				break
		out[string_id] = text.strip_edges()
	return out

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var code: String = str(cfg.get_value("locale", "lang", DEFAULT_LANG))
	if SUPPORTED.has(code):
		language = code
	_music_volume = float(cfg.get_value("audio", "music_volume", DEFAULT_VOLUME))
	_sfx_volume = float(cfg.get_value("audio", "sfx_volume", DEFAULT_VOLUME))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("locale", "lang", language)
	cfg.set_value("audio", "music_volume", _music_volume)
	cfg.set_value("audio", "sfx_volume", _sfx_volume)
	cfg.save(SETTINGS_PATH)

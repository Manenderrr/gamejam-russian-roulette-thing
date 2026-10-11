extends Node

signal language_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const LOC_DIR: String = "res://assets/loc/"
const SUPPORTED: Array[String] = ["en", "ru"]
const DEFAULT_LANG: String = "en"
const DEFAULT_VOLUME: float = 67.0
# Built-in English strings: used when the XML tables are missing from the
# build (or a key is absent), so raw keys like "hud_hp" never reach the UI.
const FALLBACK_EN: Dictionary = {
	"about_controls": "Controls: move, katana attack, gunshots (pistol, shotgun, minigun).",
	"about_genre": "Genre: action roguelike, top-down view.",
	"about_h_controls": "CONTROLS AND RESOURCES",
	"about_h_game": "THE GAME",
	"about_h_loop": "GAMEPLAY LOOP",
	"about_h_music": "MUSIC",
	"about_h_team": "TEAM",
	"about_loop": "Core loop: kill enemies to upgrade the katana or the firearm, at the player's choice. Clearing a floor grants one upgrade; enemy XP raises HP, speed and damage. Comparable titles: Vampire Survivors, Hotline Miami, DOOM. There are 40 floors. After clearing floor 40 the player plants a bomb in the center, escapes out the window with a parachute, and the evil corporation tower explodes.",
	"about_music": "Music: all written by D7TUN6 (Alexander).",
	"about_name": "KATANA-PUNK",
	"about_resources": "Resources: ammo and XP drop from enemies and are collected automatically.",
	"about_summary": "Summary: the protagonist fights a large corporation and waves of its employees, upgrading stats, katana and gun.",
	"about_team": "Made by: Artur Salyakhutdinov, Makar Guryanov, Pyotr Struin, Aust Alexander.",
	"about_title": "ABOUT",
	"death_menu": "MAIN MENU",
	"death_retry": "RETRY",
	"death_subtitle": "THE CORPORATION REMAINS",
	"death_title": "YOU DIED",
	"gun_desc_minigun": "Ultrafast, 4-bullet bursts, hold to spray",
	"gun_desc_shotgun": "High damage, 2 pellets per shot",
	"hud_ammo": "AMMO: %d / %d",
	"hud_floor": "FLOOR %d",
	"hud_hp": "HP: %d / %d",
	"hud_left": "LEFT: %d",
	"hud_stat_pts": "STAT PTS: %d",
	"hud_tab": "[TAB]",
	"hud_xp": "XP: %d / %d",
	"katana_desc_1": "Blade 64px, faster swing",
	"katana_desc_2": "Blade 72px, faster swing",
	"katana_desc_3": "Blade 80px, longer reach",
	"katana_desc_4": "Blade 88px, fastest swing",
	"katana_max": "MAX LEVEL",
	"menu_about": "ABOUT",
	"menu_exit": "EXIT",
	"menu_play": "PLAY",
	"menu_settings": "SETTINGS",
	"menu_subtitle": "> CLEAN THE FLOORS <",
	"menu_title": "KATANA-PUNK",
	"pause_continue": "CONTINUE",
	"pause_exit": "EXIT TO MENU",
	"pause_settings": "SETTINGS",
	"pause_title": "PAUSED",
	"settings_back": "BACK",
	"settings_effects": "SOUND EFFECTS",
	"settings_language": "LANGUAGE",
	"settings_music": "MUSIC",
	"settings_title": "SETTINGS",
	"up_damage": "Damage +20%",
	"up_damage_desc": "Increase damage multiplier by 20%",
	"up_hp": "HP +20",
	"up_hp_desc": "Increase max health by 20",
	"up_katana": "KATANA LENGTH Lv %d",
	"up_maxhp": "MAX HP +25",
	"up_maxhp_desc": "Increase max HP by 25 and fully heal",
	"up_speed": "Speed +30",
	"up_speed_desc": "Increase movement speed by 30",
	"upgrade_floor_cleaned": "FLOOR %d CLEANED - PICK ONE",
	"upgrade_pick": "Pick one:",
	"upgrade_title": "FLOOR CLEAR!",
	"weapon_katana": "KATANA",
	"weapon_minigun": "MINIGUN",
	"weapon_pistol": "PISTOL",
	"weapon_shotgun": "SHOTGUN",
}
const FALLBACK_RU: Dictionary = {
	"about_controls": "Управление: движение, атака катаной, выстрелы (пистолет, дробовик, миниган).",
	"about_genre": "Жанр: экшен-рогалик с видом сверху.",
	"about_h_controls": "УПРАВЛЕНИЕ И РЕСУРСЫ",
	"about_h_game": "ИГРА",
	"about_h_loop": "ГЕЙМПЛЕЙ",
	"about_h_music": "МУЗЫКА",
	"about_h_team": "КОМАНДА",
	"about_loop": "Игровой цикл: убивайте врагов, чтобы улучшить катану или огнестрел на свой выбор. За зачистку этажа даётся одно улучшение; опыт с врагов идёт в HP, скорость и урон. Похожие игры: Vampire Survivors, Hotline Miami, DOOM. Всего 40 этажей. После зачистки 40-го этажа герой закладывает бомбу в центре, выпрыгивает в окно с парашютом, и башня злой корпорации взрывается.",
	"about_music": "Музыка: всё написано D7TUN6 (Alexander).\nИспользованные треки:\nstart.ogg - broken_shit from unreleases1 on YouTube\nLucifer - 2 from Wh1te Hous3\nDrain - 3 from obskr3.e\nAC41-00050A - 4 from B TWIN\nayounemd - 4 from obskr3.e\nbetrFlonM - 5 from obskr3.e\ngoresinn - 7 from obskr3.e\nunnrR35sT - 8 from Wh1te Hous3\nD0nor - 10 from Wh1te Hous3\nPoignant - 11 from Wh1te Hous3\nend.ogg - kal.mp3 from unreleases1 on YouTube\nНаписано специально для игры:\ngamemenu.ogg\ngamebattle1.ogg",
	"about_name": "КАТАНА-ПАНК",
	"about_resources": "Ресурсы: патроны и опыт падают с врагов и подбираются автоматически.",
	"about_summary": "Герой сражается против крупной корпорации и волн её сотрудников, прокачивая характеристики, катану и огнестрел.",
	"about_team": "Авторы:\n- Артур Саляхутдинов - спрайты, персонажи\n- Гурьянов Макар - код\n- Пётр Струин - спрайты, звуки, декорации\n- Aust Alexander - код, спрайты, музыка",
	"about_title": "ОБ ИГРЕ",
	"death_menu": "ГЛАВНОЕ МЕНЮ",
	"death_retry": "ЕЩЁ РАЗ",
	"death_subtitle": "КОРПОРАЦИЯ УЦЕЛЕЛА",
	"death_title": "ТЫ ПОГИБ",
	"gun_desc_minigun": "Сверхскоростной, очереди по 4, держи для стрельбы",
	"gun_desc_shotgun": "Высокий урон, 2 дробины за выстрел",
	"hud_ammo": "ПАТРОНЫ: %d / %d",
	"hud_floor": "ЭТАЖ %d",
	"hud_hp": "ОЗ: %d / %d",
	"hud_left": "ОСТАЛОСЬ: %d",
	"hud_stat_pts": "ОЧКИ: %d",
	"hud_tab": "[TAB]",
	"hud_xp": "ОП: %d / %d",
	"katana_desc_1": "Клинок 64px, взмах быстрее",
	"katana_desc_2": "Клинок 72px, взмах быстрее",
	"katana_desc_3": "Клинок 80px, дальше достаёт",
	"katana_desc_4": "Клинок 88px, самый быстрый взмах",
	"katana_max": "МАКС. УРОВЕНЬ",
	"menu_about": "ОБ ИГРЕ",
	"menu_exit": "ВЫХОД",
	"menu_play": "ИГРАТЬ",
	"menu_settings": "НАСТРОЙКИ",
	"menu_subtitle": "> ЗАЧИСТИ ЭТАЖИ <",
	"menu_title": "КАТАНА-\nПАНК",
	"pause_continue": "ПРОДОЛЖИТЬ",
	"pause_exit": "В МЕНЮ",
	"pause_settings": "НАСТРОЙКИ",
	"pause_title": "ПАУЗА",
	"settings_back": "НАЗАД",
	"settings_effects": "ЗВУКОВЫЕ ЭФФЕКТЫ",
	"settings_language": "ЯЗЫК",
	"settings_music": "МУЗЫКА",
	"settings_title": "НАСТРОЙКИ",
	"up_damage": "Урон +20%",
	"up_damage_desc": "Увеличивает множитель урона на 20%",
	"up_hp": "HP +20",
	"up_hp_desc": "Увеличивает макс. здоровье на 20",
	"up_katana": "ДЛИНА КАТАНЫ Ур %d",
	"up_maxhp": "МАКС HP +25",
	"up_maxhp_desc": "Увеличивает макс. HP на 25 и полностью лечит",
	"up_speed": "Скорость +30",
	"up_speed_desc": "Увеличивает скорость передвижения на 30",
	"upgrade_floor_cleaned": "ЭТАЖ %d ЗАЧИЩЕН - ВЫБЕРИ ОДНО",
	"upgrade_pick": "Выбери одно:",
	"upgrade_title": "ЭТАЖ ЗАЧИЩЕН!",
	"weapon_katana": "КАТАНА",
	"weapon_minigun": "МИНИГАН",
	"weapon_pistol": "ПИСТОЛЕТ",
	"weapon_shotgun": "ДРОБОВИК",
}

var language: String = DEFAULT_LANG
var _tables: Dictionary = {}
var _music_volume: float = DEFAULT_VOLUME
var _sfx_volume: float = DEFAULT_VOLUME

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for code in SUPPORTED:
		var table: Dictionary = _load_xml(LOC_DIR + code + ".xml")
		# Built-in tables under the XML: missing files or keys still resolve.
		# XML stays on top, so edits to assets/loc/*.xml apply in the editor.
		var base: Dictionary = FALLBACK_RU if code == "ru" else FALLBACK_EN
		for key in base:
			if not table.has(key):
				table[key] = base[key]
		if code != DEFAULT_LANG:
			for key in FALLBACK_EN:
				if not table.has(key):
					table[key] = FALLBACK_EN[key]
		_tables[code] = table
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
	var text: String = str(table.get(string_id, FALLBACK_EN.get(string_id, string_id)))
	if text == string_id:
		text = string_id.replace("_", " ").to_upper()
	if args.is_empty():
		return text
	if not _format_fits(text, args.size()):
		return text
	return text % args

# Guard: a bare key (or a string without placeholders) with args would
# otherwise print raw keys like "hud_hp" with no data.
func _format_fits(text: String, arg_count: int) -> bool:
	if arg_count == 0:
		return true
	var placeholders: int = 0
	var i: int = 0
	while i < text.length():
		if text[i] == "%" and i + 1 < text.length() and text[i + 1] != "%":
			placeholders += 1
		i += 1
	return placeholders >= arg_count

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

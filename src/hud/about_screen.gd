extends CanvasLayer

signal closed

const SECTIONS: Array = [
	["about_h_game", true],
	["about_name", true],
	["about_genre", false],
	["about_summary", false],
	["about_h_loop", true],
	["about_loop", false],
	["about_h_controls", true],
	["about_controls", false],
	["about_resources", false],
	["about_h_team", true],
	["about_team", false],
	["about_h_music", true],
	["about_music", false],
]

@onready var title: Label = $Panel/VBoxContainer/Title
@onready var text_vbox: VBoxContainer = $Panel/VBoxContainer/Scroll/TextVBox
@onready var back_button: Button = $Panel/VBoxContainer/BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(hide_about)
	Loc.language_changed.connect(refresh_texts)
	refresh_texts()
	visible = false

func show_about() -> void:
	refresh_texts()
	visible = true
	GameManager.play_sfx("window")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("play_about_music"):
		gm.call("play_about_music")

func hide_about() -> void:
	GameManager.play_sfx("select")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("stop_special_music"):
		gm.call("stop_special_music")
	visible = false
	closed.emit()

func refresh_texts() -> void:
	title.text = Loc.tr_key("about_title")
	back_button.text = Loc.tr_key("settings_back")
	for c in text_vbox.get_children():
		text_vbox.remove_child(c)
		c.queue_free()
	for section in SECTIONS:
		var key: String = str(section[0])
		var is_header: bool = bool(section[1])
		var label := Label.new()
		label.text = Loc.tr_key(key)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_header:
			label.add_theme_font_size_override("font_size", 20)
		if key == "about_name":
			label.add_theme_font_size_override("font_size", 22)
			label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.53))
		elif is_header:
			label.add_theme_color_override("font_color", Color(0.15, 0.9, 1.0))
		text_vbox.add_child(label)

extends CanvasLayer

@onready var title: Label = $Panel/VBoxContainer/Title
@onready var music_label: Label = $Panel/VBoxContainer/MusicLabel
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicRow/MusicSlider
@onready var sfx_label: Label = $Panel/VBoxContainer/SfxLabel
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SfxRow/SfxSlider
@onready var lang_label: Label = $Panel/VBoxContainer/LangLabel
@onready var lang_option: OptionButton = $Panel/VBoxContainer/LangOption
@onready var back_button: Button = $Panel/VBoxContainer/BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	lang_option.add_item("English", 0)
	lang_option.add_item("Русский", 1)
	lang_option.selected = 0 if Loc.get_language() == "en" else 1
	music_slider.set_value_no_signal(Loc.get_music_volume())
	sfx_slider.set_value_no_signal(Loc.get_sfx_volume())
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	lang_option.item_selected.connect(_on_language_selected)
	back_button.pressed.connect(hide_settings)
	Loc.language_changed.connect(refresh_texts)
	refresh_texts()
	visible = false

func show_settings() -> void:
	refresh_texts()
	visible = true
	GameManager.play_sfx("window")

func hide_settings() -> void:
	GameManager.play_sfx("select")
	visible = false

func refresh_texts() -> void:
	title.text = Loc.tr_key("settings_title")
	music_label.text = Loc.tr_key("settings_music")
	sfx_label.text = Loc.tr_key("settings_effects")
	lang_label.text = Loc.tr_key("settings_language")
	back_button.text = Loc.tr_key("settings_back")

func _on_music_changed(value: float) -> void:
	Loc.set_music_volume(value)

func _on_sfx_changed(value: float) -> void:
	Loc.set_sfx_volume(value)

func _on_language_selected(index: int) -> void:
	Loc.set_language("en" if index == 0 else "ru")

extends CanvasLayer
class_name UpgradeUI

signal upgrade_selected(choice: Dictionary)

@onready var panel: Control = $Panel
@onready var container: VBoxContainer = $Panel/VBoxContainer/Choices
@onready var title: Label = $Panel/VBoxContainer/Title
@onready var wave_label: Label = $Panel/VBoxContainer/WaveLabel

var pending_choices: Array[Dictionary] = []
var base_stat_choices: Array[Dictionary] = []
var player_stats: PlayerStats
var katana: Weapon
var gun: Weapon
var current_wave_num: int = 1
var accept_input_after: float = 0.0

func _ready() -> void:
	# UI must keep processing input while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if is_instance_valid(panel):
		panel.visible = false
	Loc.language_changed.connect(_on_language_changed)

func show_upgrades(choices: Array[Dictionary], stats: PlayerStats, katana_weapon: Weapon, gun_weapon: Weapon, wave_num: int = 1) -> void:
	player_stats = stats
	katana = katana_weapon
	gun = gun_weapon
	current_wave_num = wave_num
	base_stat_choices = choices
	pending_choices = _filter_choices(base_stat_choices)

	_rebuild_texts()

	if is_instance_valid(panel):
		panel.visible = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Ignore the clicks that cleared the floor: the player is still firing.
	accept_input_after = Time.get_ticks_msec() / 1000.0 + 0.5
	GameManager.play_sfx("window")

func _rebuild_texts() -> void:
	for child in container.get_children():
		child.queue_free()

	title.text = Loc.tr_key("upgrade_title")
	wave_label.text = Loc.tr_key("upgrade_floor_cleaned", [current_wave_num])

	for choice in pending_choices:
		var btn := Button.new()
		var localized: Array = _localize_choice(choice)
		btn.text = str(localized[0])
		btn.tooltip_text = str(localized[1])
		btn.pressed.connect(_on_choice_selected.bind(choice))
		container.add_child(btn)

func _localize_choice(choice: Dictionary) -> Array:
	var text: String = str(choice.get("text", "Upgrade"))
	var desc: String = str(choice.get("description", ""))
	if choice.has("text_key"):
		var args: Array = [choice.get("text_arg")] if choice.has("text_arg") else []
		text = Loc.tr_key(str(choice["text_key"]), args)
	if choice.has("desc_key"):
		desc = Loc.tr_key(str(choice["desc_key"]))
	return [text, desc]

func _on_language_changed() -> void:
	if not visible:
		return
	pending_choices = _filter_choices(base_stat_choices)
	_rebuild_texts()

func _filter_choices(base_choices: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	var available_choices: Array[Dictionary] = []

	# Wave-clear reward (free): longer katana, max level 5.
	if katana != null and katana.can_upgrade():
		available_choices.append({
			"type": "bonus",
			"bonus": "katana",
			"text_key": "up_katana",
			"text_arg": katana.level + 1,
			"text": "KATANA LENGTH Lv " + str(katana.level + 1),
			"description": katana.get_upgrade_description()
		})

	# Wave-clear reward (free): evolve the pistol while climbing floors.
	if gun != null and gun is Gun and (gun as Gun).can_tier_up() and _tier_unlocked((gun as Gun).tier + 1):
		available_choices.append({
			"type": "bonus",
			"bonus": "gun",
			"text": (gun as Gun).tier_up_name().to_upper(),
			"description": (gun as Gun).tier_up_description()
		})

	# Wave-clear reward (free): more max HP.
	available_choices.append({
		"type": "bonus",
		"bonus": "hp",
		"text_key": "up_maxhp",
		"desc_key": "up_maxhp_desc",
		"text": "MAX HP +25",
		"description": "Increase max HP by 25 and fully heal"
	})

	# Banked XP stat points can additionally be spent here.
	if player_stats != null and player_stats.stat_points > 0:
		for choice in base_choices:
			if String(choice.get("type", "")) == "stat":
				available_choices.append(choice)

	# Pick up to 3 choices, always keeping the free wave rewards first.
	var shuffled: Array[Dictionary] = available_choices.duplicate()
	shuffled.shuffle()

	for choice in shuffled:
		if String(choice.get("type", "")) == "bonus":
			if not filtered.has(choice):
				filtered.append(choice)
	for choice in shuffled:
		if filtered.size() >= 3:
			break
		if not filtered.has(choice):
			filtered.append(choice)

	return filtered

func _tier_unlocked(next_tier: int) -> bool:
	if next_tier <= 1:
		return current_wave_num >= 2
	return current_wave_num >= 4

func _on_choice_selected(choice: Dictionary) -> void:
	if Time.get_ticks_msec() / 1000.0 < accept_input_after:
		return
	GameManager.play_sfx("select")
	upgrade_selected.emit(choice)
	_hide_ui()

func _hide_ui() -> void:
	if is_instance_valid(panel):
		panel.visible = false
	visible = false
	get_tree().paused = false
	# This game aims with a visible cursor: captured mode would hide it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

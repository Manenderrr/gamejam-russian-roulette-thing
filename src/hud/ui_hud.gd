extends CanvasLayer
class_name UIHUD

@onready var health_bar: ProgressBar = $LeftPanel/VBox/HealthBar
@onready var health_label: Label = $LeftPanel/VBox/HealthLabel
@onready var wave_label: Label = $RightPanel/VBox/WaveLabel
@onready var left_label: Label = $RightPanel/VBox/LeftLabel
@onready var ammo_label: Label = $LeftPanel/VBox/AmmoLabel
@onready var xp_bar: ProgressBar = $LeftPanel/VBox/XPBar
@onready var xp_label: Label = $LeftPanel/VBox/XPLabel
@onready var weapon_label: Label = $LeftPanel/VBox/WeaponLabel
@onready var stat_points_label: Label = $LeftPanel/VBox/StatPointsLabel

var player = null
var wave_manager: WaveManager = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	wave_manager = get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if wave_manager == null:
		var parent_node: Node = get_parent()
		if parent_node != null:
			wave_manager = parent_node.get_node_or_null("WaveManager") as WaveManager

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	var stats: PlayerStats = player.get("stats") as PlayerStats
	if stats != null:
		health_bar.max_value = stats.max_health
		health_bar.value = stats.current_health
		health_label.text = "HP: %d / %d" % [int(stats.current_health), int(stats.max_health)]

		xp_bar.max_value = stats.xp_to_next_level
		xp_bar.value = stats.xp
		xp_label.text = "XP: %d / %d" % [stats.xp, stats.xp_to_next_level]

		stat_points_label.text = "STAT PTS: %d" % stats.stat_points
		stat_points_label.visible = stats.stat_points > 0

	if wave_manager != null and is_instance_valid(wave_manager):
		left_label.text = "LEFT: %d" % wave_manager.get_enemies_left()
		wave_label.text = "FLOOR %d" % wave_manager.get_current_wave()

	var player_gun: Gun = player.get("gun") as Gun
	var current_weapon_name: String = str(player.get("current_weapon"))
	if player_gun != null:
		ammo_label.text = "AMMO: %d / %d" % [player_gun.current_ammo, player_gun.max_ammo]
		ammo_label.visible = current_weapon_name == "gun"

	weapon_label.text = "KATANA [TAB]" if current_weapon_name != "gun" else "GUN [TAB]"

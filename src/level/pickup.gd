extends Area2D
class_name Pickup

signal collected(pickup_type: String, amount: int)

const TEX_XP: Texture2D = preload("res://assets/gfx/xp/xp.png")
const TEX_AMMO: Texture2D = preload("res://assets/gfx/weapon/gun/bullet.png")
const TEX_HEAL: Texture2D = preload("res://assets/gfx/heal/heal.png")

@export var pickup_type: String = "xp"
@export var amount: int = 10
@export var attraction_range: float = 120.0
@export var attraction_speed: float = 300.0
@export var lifetime: float = 15.0

var player: Node2D = null
var timer: float = 0.0

func _ready() -> void:
	# Pickups are spawned from inside physics callbacks (enemy death),
	# so monitoring flags must be set deferred to avoid flush errors.
	set_deferred("monitoring", true)
	set_deferred("monitorable", false)
	collision_layer = 8
	collision_mask = 2

	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 16.0
		collision.shape = circle
		add_child(collision)

	_apply_look()

	add_to_group("pickups")
	body_entered.connect(_on_body_entered)

	timer = lifetime

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		queue_free()
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var distance: float = global_position.distance_to(player.global_position)
	if distance < attraction_range:
		var direction: Vector2 = (player.global_position - global_position).normalized()
		global_position += direction * attraction_speed * delta

	if distance < 28.0:
		_collect()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as Node2D
		_collect()

func _collect() -> void:
	if player != null and is_instance_valid(player):
		if pickup_type == "xp" and player.has_method("add_xp"):
			player.call("add_xp", amount)
		elif pickup_type == "ammo" and player.has_method("add_ammo"):
			player.call("add_ammo", amount)
		elif pickup_type == "heal" and player.has_method("heal"):
			player.call("heal", float(amount))
	collected.emit(pickup_type, amount)
	queue_free()

func set_pickup_type(new_type: String, amt: int) -> void:
	pickup_type = new_type
	amount = amt
	_apply_look()

func _apply_look() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	match pickup_type:
		"ammo":
			sprite.texture = TEX_AMMO
			sprite.scale = Vector2(0.5, 0.5)
			sprite.modulate = Color(1, 1, 1, 1)
		"heal":
			sprite.texture = TEX_HEAL
			sprite.scale = Vector2(0.5, 0.5)
			sprite.modulate = Color(1, 1, 1, 1)
		_:
			sprite.texture = TEX_XP
			sprite.scale = Vector2(0.5, 0.5)
			sprite.modulate = Color(1, 1, 1, 1)

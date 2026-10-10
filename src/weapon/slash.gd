extends Area2D
class_name SlashEffect

# Hotline-style katana swipe: a quick 90-degree arc toward the aim side.
# The damage zone keeps full blade reach; the blade visual stays compact
# and close to the player while it swings.

@export var damage: float = 25.0
@export var lifetime: float = 0.22
@export var swing_half_angle: float = 0.7853982 # 45 degrees each side = 90 total
@export var blade_offset: float = 30.0

var timer: float = 0.0
var base_rotation: float = 0.0
var arc_width: float = 100.0
var blade_length: float = 130.0
var visual_scale: float = 0.9
var follow: Node2D = null
var sprite: Sprite2D = null
var collision_shape: CollisionShape2D = null
var hits: Array[int] = []

func _ready() -> void:
	timer = lifetime
	monitoring = true
	monitorable = false
	collision_layer = 8
	collision_mask = 4

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(arc_width, blade_length)
		collision_shape.shape = rect
		collision_shape.position = Vector2(0, -blade_length * 0.5)
		add_child(collision_shape)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(blade_texture: Texture2D, length: float, dmg: float, blade_level: int = 1, follow_target: Node2D = null) -> void:
	damage = dmg
	blade_length = length
	follow = follow_target
	hits.clear()
	base_rotation = rotation
	rotation = base_rotation - swing_half_angle
	timer = lifetime

	# Compact visual: grows only slightly with level, stays near the player.
	visual_scale = 0.8 + 0.1 * float(clampi(blade_level, 1, 5))

	if collision_shape != null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(arc_width, blade_length)
		collision_shape.shape = rect
		collision_shape.position = Vector2(0, -blade_length * 0.5)

	if sprite != null:
		if blade_texture != null:
			sprite.texture = blade_texture
		sprite.position = Vector2(0, -blade_offset)
		sprite.scale = Vector2(visual_scale, visual_scale)
		sprite.rotation = 0.0
		sprite.modulate = Color(1, 1, 1, 1)

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		queue_free()
		return

	# Stick to the wielder so the swipe follows a moving player.
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position

	# Swing 90 degrees across the aim direction with a snappy ease-out.
	var t: float = clampf(1.0 - timer / lifetime, 0.0, 1.0)
	var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
	rotation = base_rotation - swing_half_angle + 2.0 * swing_half_angle * eased

	# Fade out at the very end of the swing.
	if sprite != null:
		var a: float = clampf(timer / (lifetime * 0.35), 0.0, 1.0)
		sprite.modulate = Color(1, 1, 1, a)

func _hit(body: Object) -> void:
	if body == null:
		return
	var id: int = body.get_instance_id()
	if id in hits:
		return
	if body.has_method("take_damage"):
		if not _has_line_of_sight(body):
			return
		hits.append(id)
		body.call("take_damage", damage)

func _has_line_of_sight(body: Object) -> bool:
	var target := body as Node2D
	if target == null:
		return true
	var from: Vector2 = global_position
	if follow != null and is_instance_valid(follow):
		from = (follow as Node2D).global_position
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, target.global_position, 1)
	return space.intersect_ray(query).is_empty()

func _on_area_entered(area: Area2D) -> void:
	_hit(area)

func _on_body_entered(body: Node2D) -> void:
	_hit(body)

func set_damage(dmg: float) -> void:
	damage = dmg

extends Area2D
class_name SlashEffect

# Hotline-style katana swipe: a quick 90-degree arc toward the aim side.
# The damage zone keeps full blade reach; the blade visual stays compact
# and close to the player while it swings.

@export var damage: float = 25.0
@export var lifetime: float = 0.22
@export var swing_half_angle: float = 0.7853982 # 45 degrees each side = 90 total
@export var blade_offset: float = 12.0

# Blade art is drawn diagonal (hilt bottom-right, tip top-left): rotate it
# onto the strike axis (-Y) and anchor the hilt at the wielder's hand.
const BLADE_ART_ANGLE := 0.66
const BLADE_ART_HILT := Vector2(18.0, 24.0)

const STRIKE_FRAMES: Array[Texture2D] = [
	preload("res://assets/gfx/animation/katana strike/strike_0.png"),
	preload("res://assets/gfx/animation/katana strike/strike_1.png"),
	preload("res://assets/gfx/animation/katana strike/strike_2.png"),
	preload("res://assets/gfx/animation/katana strike/strike_3.png"),
	preload("res://assets/gfx/animation/katana strike/strike_4.png"),
	preload("res://assets/gfx/animation/katana strike/strike_5.png"),
	preload("res://assets/gfx/animation/katana strike/strike_6.png"),
	preload("res://assets/gfx/animation/katana strike/strike_7.png"),
	preload("res://assets/gfx/animation/katana strike/strike_8.png"),
]
const STRIKE_FPS: float = 45.0
static var strike_cache: SpriteFrames = null

static func get_strike_frames() -> SpriteFrames:
	if strike_cache == null:
		strike_cache = SpriteFrames.new()
		strike_cache.add_animation("strike")
		strike_cache.set_animation_speed("strike", STRIKE_FPS)
		strike_cache.set_animation_loop("strike", false)
		for tex in STRIKE_FRAMES:
			strike_cache.add_frame("strike", tex)
	return strike_cache

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

func setup(blade_texture: Texture2D, length: float, dmg: float, _blade_level: int = 1, follow_target: Node2D = null) -> void:
	damage = dmg
	blade_length = length
	follow = follow_target
	hits.clear()
	base_rotation = rotation
	rotation = base_rotation - swing_half_angle
	timer = lifetime

	# Compact visual: scaled so the art spans the real blade reach.
	visual_scale = blade_length / 64.0
	arc_width = blade_length * 0.9

	if collision_shape != null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(arc_width, blade_length)
		collision_shape.shape = rect
		collision_shape.position = Vector2(0, -blade_length * 0.5)

	if sprite != null:
		if blade_texture != null:
			sprite.texture = blade_texture
		sprite.rotation = BLADE_ART_ANGLE
		sprite.position = Vector2(0, -blade_offset) - BLADE_ART_HILT.rotated(BLADE_ART_ANGLE) * visual_scale
		sprite.scale = Vector2(visual_scale, visual_scale)
		sprite.modulate = Color(1, 1, 1, 1)

	var flash := AnimatedSprite2D.new()
	flash.sprite_frames = get_strike_frames()
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(flash)
	# Rides the blade: sized to the reach, pinned near the tip.
	flash.position = Vector2(0, -blade_length * 0.75)
	flash.scale = Vector2.ONE * blade_length / 40.0
	flash.z_index = 10
	flash.play("strike")

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

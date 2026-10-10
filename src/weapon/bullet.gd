extends CharacterBody2D
class_name Bullet

# Collision layers: 1 = world, 2 = player, 4 = enemy, 8 = projectile.
# Player bullets hit world + enemies (mask 5), enemy bullets hit world + player (mask 3).

@export var speed: float = 400.0
@export var damage: float = 15.0
@export var lifetime: float = 3.0
@export var hostile: bool = false

var velocity_vec: Vector2 = Vector2.ZERO
var timer: float = 0.0

func _ready() -> void:
	timer = lifetime
	add_to_group("bullets")
	collision_layer = 8
	_apply_mask()
	if get_node_or_null("Sprite2D") == null:
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/gfx/weapon/gun/bullet.png") as Texture2D
		spr.scale = Vector2(0.5, 0.5)
		add_child(spr)

func _apply_mask() -> void:
	if hostile:
		collision_mask = 3
	else:
		collision_mask = 5

func set_hostile(is_hostile: bool) -> void:
	hostile = is_hostile
	collision_layer = 8
	_apply_mask()

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		queue_free()
		return

	velocity = velocity_vec
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision:
		var body: Object = collision.get_collider()
		if body != null and body.has_method("take_damage"):
			body.call("take_damage", damage)
		queue_free()

func set_bullet_velocity(vel: Vector2) -> void:
	velocity_vec = vel
	if vel.length() > 0.01:
		rotation = vel.angle()

func set_damage(dmg: float) -> void:
	damage = dmg

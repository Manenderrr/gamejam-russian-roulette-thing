extends CharacterBody2D

signal health_changed(new_heatlh: int)
@export var health: int = 10:
	get:
		return health
	set(value):
		health = value
		health_changed.emit(value)

signal ammo_changed(new_ammo: int)
@export var ammo: int = 30:
	get:
		return ammo
	set(value):
		ammo = value
		ammo_changed.emit(value)

## Walking speed in pixels per second.
@export var walking_speed: float = 250
@export var melee_collision: ShapeCast2D
@export var bullet_raycast: RayCast2D

var animation_locked := false

@export var sprite: AnimatedSprite2D

var tween: Tween

func _ready() -> void:
	health_changed.emit(health)
	ammo_changed.emit(ammo)

func reset_state() -> void:
	animation_locked = false
	sprite.animation = "walk"

func _physics_process(delta: float) -> void:
	assert(sprite, "sprite is null")
	var input_vector := Input.get_vector("go_left", "go_right", "go_up", "go_down")
	var movement := input_vector * delta * walking_speed
	var collision := move_and_collide(movement)
	if collision:
		move_and_collide(movement.slide(collision.get_normal()))
	rotate(get_local_mouse_position().angle() + PI / 2)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("melee"):
		melee()
	if event.is_action_pressed("shoot"):
		shoot()

func shoot() -> void:
	assert(sprite, "sprite is null")
	assert(bullet_raycast, "bullet_raycast is null")
	if animation_locked or ammo < 1:
		return

	print("shot")

	ammo -= 1
	bullet_raycast.force_raycast_update()
	var target := bullet_raycast.get_collider()
	if target:
		print(target)

	animation_locked = true
	sprite.play("shoot")
	sprite.animation_finished.connect(reset_state, CONNECT_ONE_SHOT)

func melee() -> void:
	assert(sprite, "sprite is null")
	assert(melee_collision, "melee_collision is null")
	if animation_locked:
		return

	print("melee")

	melee_collision.force_shapecast_update()
	for i in melee_collision.get_collision_count():
		var obj := melee_collision.get_collider(i)
		print(obj)

	animation_locked = true
	sprite.play("melee")
	sprite.animation_finished.connect(reset_state, CONNECT_ONE_SHOT)

func damage(amount: int) -> void:
	health -= amount

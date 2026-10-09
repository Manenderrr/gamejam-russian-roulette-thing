extends Node

@export var player: Node2D
@export var enemy: Node2D
var game_ended: bool = false

var tween: Tween

var current_chamber: int = 0
var live_chamber: int = 1

func shoot_yourself():
	if tween or game_ended:
		return
	if current_chamber == live_chamber:
		tween = player.create_tween()
		tween.tween_property(player, "rotation", PI / 2, 1)
	else:
		print("empty")
		current_chamber = (current_chamber + 1) % 6

func shoot_enemy():
	if tween:
		# An animation is playing
		return
	if current_chamber == live_chamber:
		tween = enemy.create_tween()
		tween.tween_property(enemy, "rotation", PI / 2, 1)
	else:
		print("empty")
		current_chamber = (current_chamber + 1) % 6

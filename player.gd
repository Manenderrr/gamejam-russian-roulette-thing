extends Node

var currentChamber: int = 0
var liveChamber: int = 1

func shoot_yourself():
	if currentChamber == liveChamber:
		print("you killed yourself")
		assert(false, "death is not implemented")
	else:
		print("empty")
		currentChamber = (currentChamber + 1) % 6

func shoot_enemy():
	if currentChamber == liveChamber:
		print("you killed him")
		assert(false, "victory is not implemented")
	else:
		print("empty")
		currentChamber = (currentChamber + 1) % 6

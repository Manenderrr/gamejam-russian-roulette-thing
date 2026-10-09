extends Sprite2D

var currentChamber: int = 0
var badChamber: int = 1

func fire():
	if currentChamber == badChamber:
		print("bad")
		assert(false, "death is not implemented")
	else:
		print("okay")
		currentChamber = (currentChamber + 1) % 6

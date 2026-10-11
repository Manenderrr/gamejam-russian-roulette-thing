extends Label

@export var format_string: String

func update(value) -> void:
	text = format_string % value

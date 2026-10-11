extends Label
## Defines an method for the Label that takes a value and uses the provided format string to set its text to the value.
##
## Intended to be used with an update signal.

@export var format_string: String

func update(value) -> void:
	text = format_string % value

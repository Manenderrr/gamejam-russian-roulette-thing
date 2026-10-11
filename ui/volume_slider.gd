extends Range

@export var bus_name: StringName = &"Master"

func _ready() -> void:
	var bus_id := AudioServer.get_bus_index(bus_name)
	var bus_volume := AudioServer.get_bus_volume_linear(bus_id) * 100
	set_value_no_signal(bus_volume)
	value_changed.emit(bus_volume)

func _value_changed(new_value: float) -> void:
	var bus_id := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_linear(bus_id, new_value / 100)

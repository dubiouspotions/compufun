extends Button
## A taskbar button for one window. Its text turns bold while it is pressed, which marks the active window.


func _ready() -> void:
	_update_variation()


func _toggled(_toggled_on: bool) -> void:
	_update_variation()


func _update_variation() -> void:
	theme_type_variation = &"TaskbarButtonActive" if button_pressed else &"TaskbarButton"

class_name TouchControls
extends CanvasLayer
## The controls that touch screens get: the trackpad and the keyboard for the Screen View and
## CompuFunDB, and in debug builds the debug strip. They show while the player's last pointer input
## was a finger, and hide at the first real mouse event (docs/ios.md).

## Emitted when [member touch_mode] changes.
signal touch_mode_changed(on: bool)

## True while the last pointer input was a finger. Starts true on a device without a mouse.
var touch_mode: bool = false:
	set(value):
		if value == touch_mode:
			return
		touch_mode = value
		touch_mode_changed.emit(value)


func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() and not OS.has_feature("pc")


func _input(event: InputEvent) -> void:
	if TouchInput.is_pointer(event):
		touch_mode = TouchInput.is_touch(event)

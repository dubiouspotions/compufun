class_name TouchInput
## Tells input that a finger made from input that a mouse or a keyboard made. Godot turns each touch
## into a mouse event too (input_devices/pointing/emulate_mouse_from_touch); that copy carries
## InputEvent.DEVICE_ID_EMULATION.


## True when [param event] came from a finger: a touch or drag event, or the mouse event that Godot
## made from one. False for a real mouse, a trackpad, a key and an action.
static func is_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return true
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


## True when [param event] moves or presses a pointer, so it decides whether the player is on touch.
## Keys and actions don't: a hardware keyboard beside a touch screen keeps the touch controls.
static func is_pointer(event: InputEvent) -> bool:
	return event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag

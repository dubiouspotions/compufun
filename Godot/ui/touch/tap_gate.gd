class_name TapGate
## Decides which pointer event clicks a thing in the world, so that a swipe doesn't click what it
## started on. A mouse clicks with its left press, as on a desktop. A finger clicks when it lifts,
## and only when it stayed within the slop of where it touched: a finger that moved further swiped or
## dragged. It reads the mouse events that Godot makes from touch (TouchInput), which the world's
## code already handles, and ignores the touch events themselves.
##
## The world's root node calls [method track] with every event, before anything in the world acts on
## it (Shop does, from _input).

static var _touched_at := Vector2.INF  # INF until the first touch is tracked
static var _strayed: bool = false


## Follows the finger for [method clicks]. [param slop] is how far, in the event's pixels, the
## finger may move from where it touched and still tap. Events that a finger didn't make are ignored.
static func track(event: InputEvent, slop: float) -> void:
	var mouse := event as InputEventMouse
	if mouse == null or not TouchInput.is_touch(mouse):
		return
	var button := mouse as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_touched_at = button.position
		_strayed = false
	elif _touched_at != Vector2.INF:
		_strayed = _strayed or mouse.position.distance_to(_touched_at) > slop


## True when [param event] clicks: a left press of a mouse, or the lift of a finger that stayed
## within the slop since it touched. Always false for a finger's press: a thing that a finger can
## drag from acts on [method presses] instead.
static func clicks(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not TouchInput.is_touch(button):
		return button.pressed
	if button.pressed:
		return false
	if _touched_at == Vector2.INF:
		push_error("TapGate: a finger lifted at %s, but no touch was tracked; the world's root must call TapGate.track from _input" % button.position)
		return false
	return not _strayed


## True when [param event] is a left press, of a mouse or a finger: for a thing that the player drags
## from, such as the VGA plug, where a finger must act on the touch as a mouse acts on the press.
static func presses(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed

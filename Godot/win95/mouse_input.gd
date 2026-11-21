class_name MouseInput
extends Node
## Makes the mouse behave as [member computer]'s Mouse settings say, for every control in this
## viewport: it swaps the left and right buttons while the setup is left-handed, and decides
## double-clicks with the setup's double_click_ms instead of the host's interval. It takes each
## mouse event in _input, before any control sees it, and pushes the translated copy instead.
## It must be the last node in its viewport that has _input. Embedded popups get their clicks
## before _input, so they see the buttons unswapped; Win95's menus take either button anyway.

## Win95's double-click rectangle is 4 x 4 pixels: the second press must land within 2 pixels of
## the first on each axis.
const DOUBLE_CLICK_REACH := 2.0

## The computer whose setup decides; while it is off, events pass unchanged.
@export var computer: ComputerState

var _pushing := false
var _last_button := MOUSE_BUTTON_NONE
var _last_ms := 0
var _last_at := Vector2.ZERO


## True when a press at [param at], [param gap_ms] after the previous press of the same button at
## [param previous_at], completes a double-click for a setup whose limit is [param limit_ms].
static func is_double_click(gap_ms: int, previous_at: Vector2, at: Vector2, limit_ms: int) -> bool:
	var offset := (at - previous_at).abs()
	return gap_ms >= 0 and gap_ms <= limit_ms and offset.x <= DOUBLE_CLICK_REACH and offset.y <= DOUBLE_CLICK_REACH


func _input(event: InputEvent) -> void:
	if _pushing:
		return
	var translated := translate(event, Time.get_ticks_msec())
	if translated == null:
		return
	var viewport := get_viewport()
	_pushing = true
	viewport.push_input(translated, true)
	_pushing = false
	viewport.set_input_as_handled()  # after the push, which clears the flag that it shares with this event


## [param event] as the desktop must see it at [param now_ms] (milliseconds, any clock that the
## caller keeps using), or null when it needs no change. A press also counts toward the next
## double-click, so call this once per event.
func translate(event: InputEvent, now_ms: int) -> InputEvent:
	var mouse := event as InputEventMouse
	if mouse == null or computer == null or not computer.is_on or computer.setup == null:
		return null
	var setup := computer.setup
	var copy := mouse.duplicate() as InputEventMouse
	if setup.left_handed:
		copy.button_mask = _swapped_mask(mouse.button_mask)
	var button := copy as InputEventMouseButton
	var changed := copy.button_mask != mouse.button_mask
	if button != null:
		if setup.left_handed:
			button.button_index = _swapped(button.button_index)
		if button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			button.double_click = _press(button.button_index, button.position, now_ms, setup.double_click_ms)
		var original := mouse as InputEventMouseButton
		changed = changed or button.button_index != original.button_index or button.double_click != original.double_click
	return copy if changed else null


func _press(index: MouseButton, at: Vector2, now_ms: int, limit_ms: int) -> bool:
	var double := index == _last_button and is_double_click(now_ms - _last_ms, _last_at, at, limit_ms)
	# A third press starts over, as in Win95.
	_last_button = MOUSE_BUTTON_NONE if double else index
	_last_ms = now_ms
	_last_at = at
	return double


static func _swapped(index: MouseButton) -> MouseButton:
	match index:
		MOUSE_BUTTON_LEFT:
			return MOUSE_BUTTON_RIGHT
		MOUSE_BUTTON_RIGHT:
			return MOUSE_BUTTON_LEFT
	return index


static func _swapped_mask(mask: int) -> int:
	var rest := mask & ~(MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)
	var left := MOUSE_BUTTON_MASK_RIGHT if mask & MOUSE_BUTTON_MASK_LEFT else 0
	var right := MOUSE_BUTTON_MASK_LEFT if mask & MOUSE_BUTTON_MASK_RIGHT else 0
	return rest | left | right

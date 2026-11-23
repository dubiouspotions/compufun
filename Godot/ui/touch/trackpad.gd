class_name Trackpad
extends Control
## A laptop trackpad for the open Screen View or CompuFunDB on a touch screen: it moves the screen's
## cursor relatively, so the player never has to hit a 2 px target with a finger. It shows while the
## parent [TouchControls] is in touch mode and a screen view is open; then the CRT itself ignores
## fingers ([member CrtScreen.takes_touch]).
##
## One finger drags the cursor; a tap clicks at it (two taps double-click, as the cursor stays put);
## a long press holds the left button for a drag; two fingers tap a right click, or drag to scroll.

## The group that the keyboard finds its trackpad by.
const GROUP: StringName = &"touch_trackpad"

## Cursor pixels per pad pixel at slow finger speed.
@export var speed: float = 0.6
## How much faster a quick finger moves the cursor: the gain grows by this per pad pixel per event.
@export var acceleration: float = 0.04
## The most that acceleration multiplies [member speed] by.
@export var max_acceleration: float = 2.0
## Pad pixels that a finger may wander before a touch counts as a drag instead of a tap.
@export var tap_slop: float = 12.0
## Seconds that a still finger holds before the left button goes down for a drag.
@export var hold_seconds: float = 0.45
## Pad pixels of two-finger drag per wheel step.
@export var scroll_step: float = 24.0
## Content follows the fingers, as on iOS: fingers up scroll down.
@export var natural_scroll: bool = true
## The pad's tint while the left button is held.
@export var held_tint: Color = Color(0.82, 0.86, 1.0)

enum _Gesture { NONE, PENDING, MOVING, DRAGGING, TWO_PENDING, SCROLLING, SPENT }

## Whether the player wants the keyboard: the keyboard key on the pad toggles it.
var keyboard_open: bool = false:
	set(value):
		keyboard_open = value
		if is_node_ready():
			_keys_button.set_pressed_no_signal(value)

var _gesture: _Gesture = _Gesture.NONE
var _fingers: Dictionary[int, Vector2] = {}
var _start: Vector2 = Vector2.ZERO  # the first finger's or the two fingers' middle, at the start
var _held: float = 0.0  # seconds since the gesture started
var _scrolled: float = 0.0  # pad pixels of scroll not yet sent as a wheel step
var _screen: CrtScreen

@onready var _pad: Control = %Pad
@onready var _keys_button: Button = %KeysButton


func _ready() -> void:
	add_to_group(GROUP)
	_pad.gui_input.connect(_on_pad_input)
	_keys_button.toggled.connect(func(on: bool) -> void: keyboard_open = on)
	_reconcile()


func _process(delta: float) -> void:
	_reconcile()
	_held += delta
	if _gesture == _Gesture.PENDING and _held >= hold_seconds:
		_gesture = _Gesture.DRAGGING
		_button(MOUSE_BUTTON_LEFT, true)


## The screen that the pad drives: the open screen view's, or null while none is open.
func screen() -> CrtScreen:
	return _screen


# Every frame: the open view and touch mode can change from anywhere.
func _reconcile() -> void:
	var controls := get_parent() as TouchControls
	var open: CrtScreen = null
	for view: ScreenView in get_tree().get_nodes_in_group(ScreenView.GROUP):
		if view.is_open():
			open = view.crt_screen()
	var shown := controls != null and controls.touch_mode and open != null
	if open != _screen or shown != visible:
		_end_gesture()
	_screen = open
	visible = shown
	for crt: CrtScreen in get_tree().get_nodes_in_group(CrtScreen.GROUP):
		crt.takes_touch = not shown


func _on_pad_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_finger_down(touch.index, touch.position)
		else:
			_finger_up(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _fingers.has(drag.index):
		_finger_moved(drag.index, drag.position)


func _finger_down(index: int, at: Vector2) -> void:
	_fingers[index] = at
	match _gesture:
		_Gesture.NONE:
			_gesture = _Gesture.PENDING
			_start = at
			_held = 0.0
		_Gesture.PENDING, _Gesture.MOVING:
			if _fingers.size() == 2:
				_gesture = _Gesture.TWO_PENDING
				_start = _middle()
				_scrolled = 0.0
				_held = 0.0


func _finger_moved(index: int, at: Vector2) -> void:
	var middle_before := _middle()
	var from: Vector2 = _fingers[index]
	_fingers[index] = at
	match _gesture:
		_Gesture.PENDING:
			if at.distance_to(_start) > tap_slop:
				_gesture = _Gesture.MOVING
				_move(at - _start)
		_Gesture.MOVING, _Gesture.DRAGGING:
			if _fingers.size() == 1:
				_move(at - from)
		_Gesture.TWO_PENDING:
			if _middle().distance_to(_start) > tap_slop:
				_gesture = _Gesture.SCROLLING
				_scroll(_middle().y - _start.y)
		_Gesture.SCROLLING:
			_scroll(_middle().y - middle_before.y)


func _finger_up(index: int) -> void:
	if not _fingers.has(index):
		return
	match _gesture:
		_Gesture.PENDING:
			_button(MOUSE_BUTTON_LEFT, true)
			_button(MOUSE_BUTTON_LEFT, false)
		_Gesture.DRAGGING:
			_button(MOUSE_BUTTON_LEFT, false)
		_Gesture.TWO_PENDING:
			if _held < hold_seconds:
				_button(MOUSE_BUTTON_RIGHT, true)
				_button(MOUSE_BUTTON_RIGHT, false)
	_fingers.erase(index)
	_gesture = _Gesture.NONE if _fingers.is_empty() else _Gesture.SPENT
	_sync_tint()


# A gesture cut short (the view closed, touch mode ended) lets go of a held button.
func _end_gesture() -> void:
	if _gesture == _Gesture.DRAGGING:
		_button(MOUSE_BUTTON_LEFT, false)
	_fingers.clear()
	_gesture = _Gesture.NONE
	_sync_tint()


func _middle() -> Vector2:
	var sum := Vector2.ZERO
	for at: Vector2 in _fingers.values():
		sum += at
	return sum / maxi(_fingers.size(), 1)


func _move(finger: Vector2) -> void:
	if _screen == null:
		return
	var gain := speed * minf(1.0 + acceleration * finger.length(), max_acceleration)
	var from := _screen.cursor_at()
	var to := (from + finger * gain).clamp(Vector2.ZERO, Vector2(_screen.buffer.size) - Vector2.ONE)
	if to == from:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	motion.button_mask = _mask()
	_screen.push_mouse(motion)


func _scroll(finger_dy: float) -> void:
	_scrolled += finger_dy
	while absf(_scrolled) >= scroll_step:
		var fingers_up := _scrolled < 0.0
		_scrolled -= signf(_scrolled) * scroll_step
		var wheel := MOUSE_BUTTON_WHEEL_DOWN if fingers_up == natural_scroll else MOUSE_BUTTON_WHEEL_UP
		_button(wheel, true)
		_button(wheel, false)


func _button(index: MouseButton, pressed: bool) -> void:
	if _screen == null:
		return
	var click := InputEventMouseButton.new()
	click.button_index = index
	click.pressed = pressed
	click.position = _screen.cursor_at()
	var bit := 1 << (index - 1)
	click.button_mask = _mask() | bit if pressed else _mask() & ~bit
	_screen.push_mouse(click)
	_sync_tint()


func _mask() -> int:
	return MOUSE_BUTTON_MASK_LEFT if _gesture == _Gesture.DRAGGING else 0


func _sync_tint() -> void:
	_pad.self_modulate = held_tint if _gesture == _Gesture.DRAGGING else Color.WHITE

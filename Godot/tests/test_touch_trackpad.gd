extends "res://tests/test.gd"
## The touch trackpad and keyboard over an open screen view: fingers on the pad move and click the
## screen's cursor, the keyboard's keys reach the screen buffer, and the panels keep their places.
## Scripts that use the Game autoload (ScreenView, Trackpad, TouchKeyboard) are reached untyped.

var _view: Control
var _controls: TouchControls
var _pad: Control
var _keyboard: Control
var _clicks: Array[InputEventMouse] = []
var _keys: KeyLog
var _state: Node


func run() -> void:
	MovablePanel.config_path = user_dir() + "touch_controls.cfg"
	await _set_up()
	check("the trackpad hides while not on touch", _pad.visible, false)
	_controls.touch_mode = true
	await process_frame
	check("on touch, with the view open, it shows", _pad.visible, true)
	check("and drives the open view's screen", _pad.call(&"screen"), _screen())
	check("the keyboard waits for its key", _keyboard.visible, false)

	var in_screen := TextEdit.new()
	_view.get_node(^"%ScreenBuffer").add_child(in_screen)
	var outside := LineEdit.new()
	root.add_child(outside)
	check("a text field in the screen never calls the OS keyboard", in_screen.virtual_keyboard_enabled, false)
	check("one outside the screen still does", outside.virtual_keyboard_enabled, true)
	in_screen.free()
	outside.free()

	_check_pointing()
	await _check_hold_drag()
	_check_two_fingers()
	await _check_direct_touch()
	await _check_keyboard()
	await _check_panels()
	_view.call(&"set_open", false)
	await process_frame
	check("a closed view hides the trackpad", _pad.visible, false)
	_controls.free()
	_view.free()
	_state.free()
	game.jobs = [] as Array[Job]


func _set_up() -> void:
	var content := Control.new()
	content.custom_minimum_size = Vector2(640, 480)
	var packed := PackedScene.new()
	check("the empty content packs", packed.pack(content), OK)
	content.free()
	_view = load("res://ui/screen_view.tscn").instantiate()
	_view.set(&"content", packed)
	root.add_child(_view)
	_controls = load("res://ui/touch/touch_controls.tscn").instantiate()
	root.add_child(_controls)
	_pad = _controls.get_node(^"Trackpad")
	_keyboard = _controls.get_node(^"Keyboard")
	await process_frame
	var buffer: SubViewport = _view.get_node(^"%ScreenBuffer")
	var target := Control.new()
	target.size = Vector2(640, 480)
	target.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			_clicks.append(event))
	buffer.add_child(target)
	_keys = KeyLog.new()
	buffer.add_child(_keys)
	buffer.add_child(_mouse_input())
	_view.call(&"set_open", true)
	await process_frame


# Win95's MouseInput for a running computer, which decides double-clicks.
func _mouse_input() -> Node:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var customer := Customer.new()
	customer.computer = computer
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	game.jobs = [job] as Array[Job]
	_state = load("res://win95/computer_state.gd").new()
	_state.job = job
	root.add_child(_state)
	var mouse: Node = load("res://win95/mouse_input.gd").new()
	mouse.computer = _state
	return mouse


func _check_pointing() -> void:
	var at := _pad_center()
	var from := _cursor()
	_touch(0, at, true)
	for step in 6:
		_drag(0, at + Vector2(10 * (step + 1), 0), Vector2(10, 0))
	_touch(0, at + Vector2(60, 0), false)
	var moved := _cursor().x - from.x
	check("a slow drag moves the cursor right, a little less than the finger", moved > 30.0 and moved < 60.0, true)
	check("by none down", _cursor().y, from.y)
	check("and clicks nothing", _clicks.size(), 0)

	_tap(0, at)
	check("a tap clicks the left button at the cursor", _buttons(), [[MOUSE_BUTTON_LEFT, true, false], [MOUSE_BUTTON_LEFT, false, false]])
	check("where the cursor is", _clicks[0].position, _cursor())
	_clicks.clear()
	_tap(0, at)
	check("a second tap is Win95's double-click", _buttons()[0], [MOUSE_BUTTON_LEFT, true, true])
	_clicks.clear()


func _check_hold_drag() -> void:
	var at := _pad_center()
	_touch(0, at, true)
	for frame in ceili(_pad.get(&"hold_seconds") * FPS) + 2:
		await process_frame
	check("a held finger presses the left button", _buttons(), [[MOUSE_BUTTON_LEFT, true, false]])
	var from := _cursor()
	_drag(0, at + Vector2(0, 20), Vector2(0, 20))
	check("and drags with it held", _cursor().y > from.y, true)
	_touch(0, at + Vector2(0, 20), false)
	check("lifting releases it", _buttons()[-1], [MOUSE_BUTTON_LEFT, false, false])
	_clicks.clear()


func _check_two_fingers() -> void:
	var at := _pad_center()
	_touch(0, at, true)
	_touch(1, at + Vector2(40, 0), true)
	_touch(0, at, false)
	_touch(1, at + Vector2(40, 0), false)
	check("a two-finger tap right-clicks", _buttons(), [[MOUSE_BUTTON_RIGHT, true, false], [MOUSE_BUTTON_RIGHT, false, false]])
	_clicks.clear()

	_touch(0, at, true)
	_touch(1, at + Vector2(40, 0), true)
	for step in 4:
		_drag(0, at - Vector2(0, 20 * (step + 1)), Vector2(0, -20))
		_drag(1, at + Vector2(40, -20 * (step + 1)), Vector2(0, -20))
	_touch(0, at - Vector2(0, 80), false)
	_touch(1, at + Vector2(40, -80), false)
	var wheel := _buttons().filter(func(b: Array) -> bool: return b[1])
	check("two fingers up scroll the wheel down", wheel.map(func(b: Array) -> MouseButton: return b[0]), [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN])
	_clicks.clear()


func _check_direct_touch() -> void:
	var on_glass := Vector2(200, 200)
	_tap(0, on_glass)
	check("a finger on the glass does nothing while the trackpad shows", _clicks.size(), 0)
	check("and leaves the view open", _view.call(&"is_open"), true)
	_mouse(on_glass)
	check("a real mouse still points directly", _buttons().size(), 2)
	check("and ends touch mode", _controls.touch_mode, false)
	await process_frame
	check("which hides the trackpad", _pad.visible, false)
	_clicks.clear()
	_controls.touch_mode = true
	await process_frame


func _check_keyboard() -> void:
	(_pad.get_node(^"%KeysButton") as Button).button_pressed = true
	await process_frame
	check("the KEYS button shows the keyboard", _keyboard.visible, true)
	await process_frame  # the containers lay out the keys
	for n: String in ["Ctrl", "Alt", "Delete", "A", "Shift"]:
		var k := _keyboard.find_child(n, true, false) as Control
	_tap(0, _key_center("Ctrl"))
	_tap(0, _key_center("Alt"))
	_tap(1, _key_center("Delete"))  # a second finger types too
	var presses := _keys.pressed()
	check("Ctrl, Alt, Del reach the buffer as one chord", presses.map(_chord), [[KEY_DELETE, true, true, false, 0]])
	_keys.events.clear()
	_tap(0, _key_center("Shift"))
	_tap(0, _key_center("A"))
	_tap(0, _key_center("A"))
	check("Shift types one capital, then lower case", _keys.pressed().map(_chord), [[KEY_A, false, false, true, 65], [KEY_A, false, false, false, 97]])
	check("each press has its release", _keys.events.size(), 4)
	_keys.events.clear()


func _check_panels() -> void:
	var panel: MovablePanel = _pad.get_node(^"Panel")
	var grip: Control = panel.grip
	var from := panel.position
	var at := grip.get_global_rect().get_center()
	_mouse_drag(at, at + Vector2(300, -200))
	check("the grip drags the trackpad", panel.position, from + Vector2(300, -200))
	var saved := ConfigFile.new()
	check("letting go saves its place", saved.load(MovablePanel.config_path), OK)
	check("as the position", saved.get_value("trackpad", "position", null), panel.position)
	panel.place(Vector2(5000, -50))
	check("it stays inside the window", panel.position, Vector2(_pad.size.x - panel.size.x, 0))
	check("a saved place round-trips", panel.save_position(), OK)

	var again: Node = load("res://ui/touch/touch_controls.tscn").instantiate()
	root.add_child(again)
	await process_frame
	check("a new trackpad starts where the last one was left", (again.get_node(^"Trackpad/Panel") as Control).position, panel.position)
	check("the keyboard keeps its default", (again.get_node(^"Keyboard/Panel") as MovablePanel).position, (again.get_node(^"Keyboard/Panel") as MovablePanel).default_position)
	again.free()

	var file := FileAccess.open(MovablePanel.config_path, FileAccess.WRITE)
	file.store_string("[trackpad]\nposition=\"left\"\n")
	file.close()
	again = load("res://ui/touch/touch_controls.tscn").instantiate()
	root.add_child(again)
	await process_frame
	var fallback: MovablePanel = again.get_node(^"Trackpad/Panel")
	check("a wrong value falls back to the default", fallback.position, fallback.default_position)
	again.free()


func _screen() -> Control:
	return _view.call(&"crt_screen")


func _cursor() -> Vector2:
	return _screen().call(&"cursor_at")


func _pad_center() -> Vector2:
	return (_pad.get_node(^"%Pad") as Control).get_global_rect().get_center()


func _key_center(key_name: String) -> Vector2:
	var key := _keyboard.find_child(key_name, true, false) as Control
	return key.get_global_rect().get_center()


# [button, pressed, double_click] of each click that reached the buffer.
func _buttons() -> Array:
	return _clicks.map(func(e: InputEventMouseButton) -> Array: return [e.button_index, e.pressed, e.double_click])


func _chord(key: InputEventKey) -> Array:
	return [key.keycode, key.ctrl_pressed, key.alt_pressed, key.shift_pressed, key.unicode]


func _tap(index: int, at: Vector2) -> void:
	_touch(index, at, true)
	_touch(index, at, false)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	_send(touch)


func _drag(index: int, at: Vector2, relative: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = at
	drag.relative = relative
	_send(drag)


func _mouse(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		_send(click)


# The mouse twin of a finger, as Godot makes it, so the move doesn't end touch mode.
func _mouse_drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.device = InputEvent.DEVICE_ID_EMULATION
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	_send(press)
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(motion)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = to
	_send(release)


# [param event] at design-frame coordinates, through Input as the OS would send it, so that Godot
# makes the mouse twin of the first finger. The headless window is 64 x 64 px.
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()


class KeyLog extends Node:
	var events: Array[InputEventKey] = []

	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			events.append(event)

	func pressed() -> Array:
		return events.filter(func(e: InputEventKey) -> bool: return e.pressed)

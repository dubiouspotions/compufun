extends "res://tests/test.gd"
## The desktop's mouse: the left-handed button swap, double-clicks at the setup's speed, and the
## pointer trail. Scripts that name ComputerState load at run time.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"
const MOUSE_INPUT_PATH := "res://win95/mouse_input.gd"
const TRAILS_PATH := "res://win95/pointer_trails.gd"


func run() -> void:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var c := Customer.new()
	c.computer = computer
	c.problem = Problem.new()
	var job := Job.new(c, 0, 0)
	job.powered = true
	game.jobs = [job] as Array[Job]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame
	check("the computer runs", state.is_on, true)

	await _check_buttons(state)
	_check_double_click(state)
	_check_trails(state)

	state.free()
	game.jobs = [] as Array[Job]


func _check_buttons(state: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	root.add_child(viewport)
	var target := Control.new()
	target.size = Vector2(640, 480)
	viewport.add_child(target)
	var got: Array[InputEvent] = []
	target.gui_input.connect(func(event: InputEvent) -> void: got.append(event))
	var mouse: Node = load(MOUSE_INPUT_PATH).new()
	mouse.computer = state
	viewport.add_child(mouse)
	await process_frame

	viewport.push_input(_button(MOUSE_BUTTON_LEFT, true, Vector2(10, 10)), true)
	viewport.push_input(_button(MOUSE_BUTTON_LEFT, false, Vector2(10, 10)), true)
	check("right-handed passes the left button", got.map(func(e: InputEventMouseButton) -> MouseButton: return e.button_index), [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_LEFT])
	got.clear()
	state.apply_settings({&"left_handed": true} as Dictionary[StringName, Variant])
	viewport.push_input(_button(MOUSE_BUTTON_LEFT, true, Vector2(300, 10)), true)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(305, 10)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(drag, true)
	viewport.push_input(_button(MOUSE_BUTTON_LEFT, false, Vector2(305, 10)), true)
	viewport.push_input(_button(MOUSE_BUTTON_RIGHT, true, Vector2(100, 10)), true)
	check("left-handed swaps every button event once", got.size(), 4)
	if got.size() == 4:
		check("a left press arrives as a right press", [(got[0] as InputEventMouseButton).button_index, (got[0] as InputEventMouseButton).pressed], [MOUSE_BUTTON_RIGHT, true])
		check("a left drag holds the right button", (got[1] as InputEventMouseMotion).button_mask, MOUSE_BUTTON_MASK_RIGHT)
		check("the release follows", (got[2] as InputEventMouseButton).button_index, MOUSE_BUTTON_RIGHT)
		check("a right press arrives as a left press", (got[3] as InputEventMouseButton).button_index, MOUSE_BUTTON_LEFT)
	state.apply_settings({&"left_handed": false} as Dictionary[StringName, Variant])
	viewport.free()


func _check_double_click(state: Node) -> void:
	var script: GDScript = load(MOUSE_INPUT_PATH)
	check("within the limit", script.is_double_click(300, Vector2(5, 5), Vector2(7, 3), 500), true)
	check("too slow", script.is_double_click(600, Vector2(5, 5), Vector2(5, 5), 500), false)
	check("too far", script.is_double_click(100, Vector2(5, 5), Vector2(8, 5), 500), false)

	var mouse: Node = script.new()
	mouse.computer = state
	state.apply_settings({&"double_click_ms": 500} as Dictionary[StringName, Variant])
	var presses: Array = [0, 300, 450, 2000, 2600]
	var doubles: Array = presses.map(func(ms: int) -> bool: return _is_double(mouse, ms))
	check("500 ms: a double, then a fresh click, then too slow", doubles, [false, true, false, false, false])
	state.apply_settings({&"double_click_ms": 200} as Dictionary[StringName, Variant])
	check("200 ms: 300 ms apart is two clicks", [_is_double(mouse, 5000), _is_double(mouse, 5300)], [false, false])
	state.apply_settings({&"double_click_ms": 900} as Dictionary[StringName, Variant])
	check("900 ms: 800 ms apart is a double", [_is_double(mouse, 8000), _is_double(mouse, 8800)], [false, true])
	var host_double := _button(MOUSE_BUTTON_LEFT, true, Vector2(10, 10))
	host_double.double_click = true
	var translated: InputEvent = mouse.translate(host_double, 20000)
	check("the host's double-click flag doesn't count", translated != null and not (translated as InputEventMouseButton).double_click, true)
	mouse.free()


func _check_trails(state: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	root.add_child(viewport)
	var screen_script := GDScript.new()
	screen_script.source_code = "extends Control\nvar pointer_visible := true\n"
	check("the screen stand-in compiles", screen_script.reload(), OK)
	var screen := Control.new()
	screen.set_script(screen_script)
	viewport.add_child(screen)
	var trails: Control = load(TRAILS_PATH).new()
	trails.computer = state
	trails.screen = screen
	viewport.add_child(trails)
	var step: float = trails.sample_seconds

	state.apply_settings({&"pointer_trails": 0} as Dictionary[StringName, Variant])
	trails.call(&"_process", step)
	check("no trail while pointer_trails is 0", trails.trail.size(), 0)
	state.apply_settings({&"pointer_trails": 3} as Dictionary[StringName, Variant])
	for x in [10, 20, 30, 40, 50]:
		_move(viewport, Vector2(x, 100))
		trails.call(&"_process", step)
	check("3 ghosts behind the pointer", trails.ghosts(), PackedVector2Array([Vector2(20, 100), Vector2(30, 100), Vector2(40, 100)]))
	for i in 4:
		trails.call(&"_process", step)
	check("they catch up while it rests", trails.ghosts().size(), 0)
	_move(viewport, Vector2(60, 100))
	trails.call(&"_process", step)
	screen.set(&"pointer_visible", false)
	trails.call(&"_process", step)
	check("a hidden pointer leaves no trail", trails.trail.size(), 0)
	state.apply_settings({&"pointer_trails": 0} as Dictionary[StringName, Variant])
	viewport.free()


func _is_double(mouse: Node, ms: int) -> bool:
	var translated: InputEvent = mouse.translate(_button(MOUSE_BUTTON_LEFT, true, Vector2(10, 10)), ms)
	return translated != null and (translated as InputEventMouseButton).double_click


func _move(viewport: SubViewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	viewport.push_input(motion, true)


func _button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = index
	button.pressed = pressed
	button.position = at
	return button

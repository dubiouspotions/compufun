extends "res://tests/test.gd"
## Mouse Properties: the pages' pending settings, the left-handed button swap, double-clicks at
## the setup's speed, and the pointer trail. Scripts that name ComputerState load at run time.

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
	var setup: Win95Setup = state.setup
	check("the computer runs", state.is_on, true)

	_check_pages(state, setup)
	await _check_buttons(state)
	_check_double_click(state)
	_check_trails(state)

	state.free()
	game.jobs = [] as Array[Job]


func _check_pages(state: Node, setup: Win95Setup) -> void:
	var desktop: Control = load("res://win95/desktop.gd").new()
	desktop.computer = state
	root.add_child(desktop)
	var sheet: Node = load("res://win95/applets/mouse.tscn").instantiate()
	desktop.add_child(sheet)
	var tabs: Node = sheet.get_node("%Tabs")
	check("four tabs", tabs.get_children().map(func(n: Node) -> String: return n.name), ["Buttons", "Pointers", "Motion", "General"])
	var buttons: Node = tabs.get_node("Buttons")
	var motion: Node = tabs.get_node("Motion")
	check("Buttons loads the setup", buttons.call(&"pending"), {&"left_handed": false, &"double_click_ms": 500})
	var left: CheckBox = sheet.get_node("%LeftHanded")
	left.button_pressed = true
	check("Left-handed is pending", buttons.call(&"pending")[&"left_handed"], true)
	check("the picture and the texts swap", [(sheet.get_node("%Picture") as TextureRect).texture, (sheet.get_node("%LeftButton") as Label).text],
		[buttons.get(&"left_handed_picture"), buttons.get(&"menu_text")])
	check("an edit enables Apply", (sheet.get_node("%Apply") as Button).disabled, false)
	var speed: HSlider = sheet.get_node("%DoubleClick")
	speed.value = speed.max_value
	check("Fast is the shortest gap", buttons.call(&"pending")[&"double_click_ms"], 100)
	speed.value = speed.min_value
	check("Slow is the longest gap", buttons.call(&"pending")[&"double_click_ms"], 900)
	var jack: AtlasTexture = (sheet.get_node("%Jack") as TextureRect).texture
	var test_area: Control = sheet.get_node("%TestArea")
	test_area.gui_input.emit(_button(MOUSE_BUTTON_LEFT, true, Vector2(40, 40)))
	check("one click leaves the jack in its box", jack.region.position.x, 0.0)
	test_area.gui_input.emit(_button(MOUSE_BUTTON_LEFT, true, Vector2(40, 40)))
	check("a double-click pops it out", jack.region.position.x > 0.0, true)

	check("Motion loads no trail", motion.call(&"pending"), {&"pointer_speed": 3, &"pointer_trails": 0})
	var length: HSlider = sheet.get_node("%TrailLength")
	check("the trail slider is greyed at Long", [length.editable, length.value], [false, 7.0])
	(sheet.get_node("%ShowTrails") as CheckBox).button_pressed = true
	check("ticking shows a Long trail", [length.editable, motion.call(&"pending")[&"pointer_trails"]], [true, 7])
	length.value = length.min_value
	(sheet.get_node("%Speed") as HSlider).value = 6
	check("Short and fast", motion.call(&"pending"), {&"pointer_speed": 6, &"pointer_trails": 2})
	(sheet.get_node("%ShowTrails") as CheckBox).button_pressed = false
	check("unticked is no trail", motion.call(&"pending")[&"pointer_trails"], 0)

	(sheet.get_node("%Apply") as Button).pressed.emit()
	check("Apply sets the copy", [setup.left_handed, setup.double_click_ms, setup.pointer_speed, setup.pointer_trails], [true, 900, 6, 0])
	sheet.free()

	state.apply_settings({&"pointer_trails": 4, &"left_handed": false, &"double_click_ms": 500} as Dictionary[StringName, Variant])
	sheet = load("res://win95/applets/mouse.tscn").instantiate()
	desktop.add_child(sheet)
	check("a trail loads ticked", [(sheet.get_node("%ShowTrails") as CheckBox).button_pressed, (sheet.get_node("%TrailLength") as HSlider).value], [true, 4.0])
	check("an unedited sheet keeps Apply grey", (sheet.get_node("%Apply") as Button).disabled, true)
	desktop.free()


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

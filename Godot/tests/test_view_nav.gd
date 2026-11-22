extends "res://tests/test.gd"
## The keys between views: Up or W in the Left View enters the storage room, as a click on the
## storage door does, and Back returns to the Left View. No key or click skips the work computer's
## start-up, and S leaves CompuFunDB while it goes on.

var _main: Node


func run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	game.go_to_view(&"Left")

	_press(&"look_up")
	check("Up in the Left View enters the storage room", game.view, &"Storage")
	_press(&"go_back")
	check("Back in the storage room returns to the Left View", game.view, &"Left")

	var door: Hotspot = _main.get_node("%Shop").find_child("StorageDoor", true, false)
	door.clicked.emit(door)
	check("a click on the storage door goes to the same view", game.view, &"Storage")

	game.go_to_view(&"Main")
	_press(&"look_up")
	check("Up in the Main View still looks up at the ceiling", game.view, &"Up")
	await _check_db_start_up()
	_main.queue_free()


func _check_db_start_up() -> void:
	var view: Control = _main.get_node("%CompuFunDBView")
	var db: Control = view.find_child("CompuFunDB", true, false)
	game.go_to_view(&"CompuFunDB")
	for i: int in 60:
		await process_frame
	var screen: Control = view.get_node("%Screen")
	for key: Key in [KEY_A, KEY_SPACE, KEY_ENTER, KEY_F4]:
		_press_key(key)
	_click(screen.get_global_rect().get_center())
	for i: int in 5:
		await process_frame
	var boot: Control = db.find_child("BootSequence", false, false)
	check("keys and clicks don't skip the boot", [db.get("_starting"), boot != null and boot.visible, game.db_day], [true, true, 0])
	_press_key(KEY_S)
	check("S leaves CompuFunDB during the start-up", game.view, &"Right")
	await process_frame
	check("the start-up goes on", [db.get("_starting"), is_instance_valid(boot) and boot.visible], [true, true])


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

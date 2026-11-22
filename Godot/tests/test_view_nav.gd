extends "res://tests/test.gd"
## The keys between views: Up or W in the Left View enters the storage room, as a click on the
## storage door does, and Back returns to the Left View. No key or click skips the work computer's
## start-up. In CompuFunDB, during the start-up and after it, S and Esc go back as the Back button does.
## A turn, with a key or a button, shows its button pressed down for a moment.

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
	await _check_press()
	await _check_workview_computers()
	await _check_db_start_up()
	_main.queue_free()


func _check_press() -> void:
	var nav: Control = _main.get_node("%ViewNav")
	var hold: float = nav.get("press_seconds") + 0.1
	game.go_to_view(&"Left")
	await create_timer(hold).timeout
	check("Right is up before a turn", nav.call("is_pressed_down", &"right"), false)
	_press(&"turn_right")
	check("the right arrow key turns and presses Right down", [game.view, nav.call("is_pressed_down", &"right")], [&"Main", true])
	await create_timer(hold).timeout
	check("Right comes back up", nav.call("is_pressed_down", &"right"), false)
	(nav.get_node("%LeftButton") as Button).pressed.emit()
	check("a click on Left turns and presses it down", [game.view, nav.call("is_pressed_down", &"left")], [&"Left", true])


# In the Workview, Left and Right move the focus to the computer beside it, in slot order, and stop
# at either end; the part in the hand stays there. With one computer they don't show.
func _check_workview_computers() -> void:
	var nav: Control = _main.get_node("%ViewNav")
	var jobs: Array = []
	for i: int in 3:
		jobs.append({"customer": ["res://customers/skater_bro.tres", "res://customers/retired_accountant.tres", "res://customers/activist_guy.tres"][i],
				"problem": "dust_overheat", "slot": i, "order": i})
	jobs[0]["lying"] = true
	check("restore three computers, the left one in focus and lying", game.restore({"jobs": jobs, "focus_slot": 0, "view": "Workview", "hand": ["ram"]}), "")
	await process_frame
	var left: Button = nav.get_node("%LeftButton")
	var right: Button = nav.get_node("%RightButton")
	check("at the left end only Right shows", [left.visible, right.visible], [false, true])
	var path: Array[int] = []
	for action: StringName in [&"turn_right", &"turn_right", &"turn_right", &"turn_left", &"turn_left", &"turn_left"]:
		_press(action)
		path.append(game.focus.slot)
	check("Right goes 0 to 1 to 2 and stops, Left goes back to 0 and stops", path, [1, 2, 2, 1, 0, 0])
	check("still in the Workview, the part still in the hand", [game.view, game.hand != null], [&"Workview", true])
	right.pressed.emit()
	check("the Right button moves the focus too", [game.focus.slot, left.visible, right.visible], [1, true, true])
	jobs.resize(1)
	check("restore one computer", game.restore({"jobs": jobs, "focus_slot": 0, "view": "Workview"}), "")
	await process_frame
	check("with one computer neither shows", [left.visible, right.visible], [false, false])


func _check_db_start_up() -> void:
	var view: Control = _main.get_node("%CompuFunDBView")
	var db: Control = view.find_child("CompuFunDB", true, false)
	game.start_db()
	await _check_back_keys("in the database")
	var state: Dictionary = game.snapshot()
	state.db_day = 0
	check("the work computer is off again", game.restore(state), "")
	game.go_to_view(&"CompuFunDB")
	for i: int in 60:
		await process_frame
	var screen: Control = view.get_node("%Screen")
	for key: Key in [KEY_A, KEY_SPACE, KEY_ENTER, KEY_F6]:
		_press_key(key)
	_click(screen.get_global_rect().get_center())
	for i: int in 5:
		await process_frame
	var boot: Control = db.find_child("BootSequence", false, false)
	check("keys and clicks don't skip the boot", [db.get("_starting"), boot != null and boot.visible, game.db_day], [true, true, 0])
	await _check_back_keys("during the start-up")
	check("the start-up goes on", [db.get("_starting"), is_instance_valid(boot) and boot.visible], [true, true])


# S, Esc and the Back button each take CompuFunDB back to the Right View.
func _check_back_keys(when: String) -> void:
	var back: Button = _main.get_node("%ViewNav").get_node("%BackButton")
	for key: Key in [KEY_S, KEY_ESCAPE, KEY_NONE]:
		game.go_to_view(&"CompuFunDB")
		await process_frame
		if key == KEY_NONE:
			back.pressed.emit()
		else:
			_press_key(key)
		check("%s goes back %s" % ["Back" if key == KEY_NONE else OS.get_keycode_string(key), when], game.view, &"Right")


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

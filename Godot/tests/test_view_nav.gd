extends "res://tests/test.gd"
## The keys between views: Up or W in the Left View enters the storage room, as a click on the
## storage door does, and Back returns to the Left View.

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
	_main.queue_free()


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

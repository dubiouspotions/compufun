extends "res://tests/test.gd"
## The Clippy scare in the storage room holds the player still and hides the turn buttons until the
## lights are back, then gives both back and is done.


func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	game.restore({"day": 6, "phase": "CLOSED", "view": "Left", "flags": {"sign_clippy_jumpscare": 1}})
	await process_frame
	var nav: Control = main.get_node("%ViewNav")
	game.go_to_view(&"Storage")
	await process_frame
	check("the turn buttons hide", nav.visible, false)
	_press(&"go_back")
	check("Back does nothing during the scare", game.view, &"Storage")
	await create_timer(12.0).timeout
	check("the scare is done", game.flag(&"sign_clippy_jumpscare"), 2)
	check("the turn buttons are back", nav.visible, true)
	_press(&"go_back")
	check("Back works again", game.view, &"Left")


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

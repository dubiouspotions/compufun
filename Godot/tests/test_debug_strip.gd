extends "res://tests/test.gd"
## The debug strip's buttons send the keys of the debug tools' actions, and the tools' own key
## handlers answer them (ui/touch/debug_strip.gd).

const ACTIONS: Array[StringName] = [&"debug_menu", &"dev_menu", &"story_lab", &"feedback", &"skip_ahead"]


class KeyCatcher extends Node:
	var actions: Array[StringName] = []

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key == null or not key.pressed:
			return
		for action: StringName in ACTIONS:
			if key.is_action_pressed(action):
				actions.append(action)


func run() -> void:
	var strip_script: GDScript = load("res://ui/touch/debug_strip.gd")  # by path: it names main.gd, which names Game
	for action: StringName in ACTIONS:
		var key: InputEventKey = strip_script.call(&"key_of", action)
		check("%s has a key" % action, key != null, true)
		if key != null:
			key.pressed = true
			check("the pressed key is %s" % action, key.is_action_pressed(action), true)

	var strip: Control = load("res://ui/touch/debug_strip.tscn").instantiate()
	root.add_child(strip)
	await process_frame
	check("hidden without touch", strip.visible, false)
	strip.call("show_for", true)
	check("shown on touch in a debug build", strip.visible, true)
	var names := PackedStringArray()
	for button: Node in strip.find_children("*", "Button", true, false):
		names.append(button.name)
		check("%s takes its touches" % button.name, (button as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	check("a button per tool, with the Dev menu in this build", names, PackedStringArray(["debug_menu", "dev_menu", "story_lab", "feedback", "skip_ahead"]))

	var catcher := KeyCatcher.new()
	root.add_child(catcher)
	strip.call("press", &"skip_ahead")
	Input.flush_buffered_events()
	check("Skip arrives as skip_ahead (Cmd+N)", catcher.actions, [&"skip_ahead"] as Array[StringName])

	var debug_menu: Node = load("res://ui/debug_menu.tscn").instantiate()
	root.add_child(debug_menu)
	await process_frame
	_button(strip, "debug_menu").pressed.emit()
	Input.flush_buffered_events()
	check("F2 opens the debug menu", debug_menu.call("is_open"), true)

	var dev_menu: Node = load("res://dev/dev_menu.tscn").instantiate()
	root.add_child(dev_menu)
	await process_frame
	_button(strip, "dev_menu").pressed.emit()
	Input.flush_buffered_events()
	check("F3 opens the Dev menu", (dev_menu.get_node("%Panel") as Control).visible, true)

	var feedback: Node = load("res://ui/feedback_screen.tscn").instantiate()
	root.add_child(feedback)
	await process_frame
	_button(strip, "feedback").pressed.emit()
	check("the strip hides for the screenshot", strip.visible, false)
	for i: int in 4:
		await process_frame
	check("F9 opens the feedback screen", feedback.call("is_open"), true)
	check("the strip is back", strip.visible, true)
	feedback.call("close")


func _button(strip: Node, action: String) -> Button:
	return strip.find_child(action, true, false) as Button

extends "res://tests/test.gd"
## Day 1's tutorial (0101) points things out with looks: the view turns at the tagged lines, the lines
## said while the player looks away show in the call-out box and go on by themselves or with a click,
## the player can face him again on their own, and the choices come facing him. Turning away on one's
## own still hushes the conversation. A conversation that looks away from its first line, and whose
## choices come without a [look ahead], turns the player back to answer.

const LOOK_FIRST := """customer: skater_bro

== drop-off
(neutral) Look over there. [look right]
(neutral) See it?
- Yes.
	(happy) Good.
"""

var _main: Node
var _box: Control
var _calling: Control


func run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	_box = _main.get_node("%DialogueOverlay")
	_calling = _main.get_node("%CustomerCalling")
	game.start_day(game.day_of(1))
	await process_frame
	check("the middle manager is in before opening, and talks in the box at once, facing the player", [game.phase, game.visitor.resource_path, game.view, _box.visible, _said()],
		[game.Phase.CLOSED, "res://customers/middle_manager.tres", &"Main", true, "...so as mentioned I'm off for vacation. I'll need you to mind the store for me until I'm back."])

	game.go_to_view(&"Left")
	await create_timer(6.0).timeout
	check("turning away on one's own hushes the line: the box hides, and the conversation waits", [_box.visible, _said(), _calling_line() == _said()], [false, "...so as mentioned I'm off for vacation. I'll need you to mind the store for me until I'm back.", false])
	game.go_to_view(&"Main")
	await process_frame
	check("facing him again, the box says the same line", [_box.visible, _said()], [true, "...so as mentioned I'm off for vacation. I'll need you to mind the store for me until I'm back."])

	await _click_box_until("You find it over there on your right, in the office area.")
	check("[look right] turns the view to the work computer, and the line shows in the call-out box", [game.view, _box.visible, _calling.visible, _calling_line()], [&"Right", false, true, "You find it over there on your right, in the office area."])
	var next := "It's that old machine: Just boot it up every morning."
	var waited := 0.0
	while _calling_line() != next and waited < 30.0:
		await create_timer(0.5).timeout
		waited += 0.5
	check("without the player, the next line comes in the call-out box once the voice ended and it was read", [_calling_line(), game.view], [next, &"Right"])

	game.go_to_view(&"Main")
	await process_frame
	check("facing him on their own, the line goes on in the box", [_box.visible, _said(), _calling.visible], [true, next, false])
	await _click_box_until("Connect the customers computer to the testing screen here on the counter and press power to solve software issues.")
	check("[look ahead] while facing him keeps the view", [game.view, _box.visible], [&"Main", true])

	await _click_box_until("The storage is that closet to the left:")
	check("[look left] turns the view to the storage side, the line in the call-out box", [game.view, _box.visible, _calling_line()], [&"Left", false, "The storage is that closet to the left:"])
	_calling.call(&"_on_click", _left_click())
	await process_frame
	check("a click on the call-out box goes on in it", [game.view, _calling_line()], [&"Left", "Just pop in there and grab what you need"])
	_calling.call(&"_on_click", _left_click())
	await process_frame
	check("the next click goes on, and [look ahead] brings the view back to him", [game.view, _box.visible, _calling.visible, _said()], [&"Main", true, false, "You got all that!?"])
	(_box.get_node("%LineLabel") as TypedLabel).finish()
	_box.call(&"_on_click", _left_click())
	await process_frame
	check("the choices show, facing him", _choices().map(func(b: Button) -> String: return b.text), ["> Uhm..", "> Well.."])

	_choices()[0].pressed.emit()
	await create_timer(1.0).timeout
	check("both choices lead to the goodbye", _said(), "GREAT!")
	await _click_box_until("")
	check("after the goodbye he leaves", game.visitor_state in [game.VisitorState.WALKING_OUT, game.VisitorState.OUTSIDE, game.VisitorState.NONE], true)

	var errand := StoryFormat.parse_errand(LOOK_FIRST, "res://story/errands/0101_skater_bro.errand").value as Errand
	game.start_day(make_day(1, [[errand.customer, load("res://problems/dust_overheat.tres"), errand.conversations]]))
	game.open_shop()
	tick(1.0)
	await process_frame
	_main.get_node("%Shop").call(&"skip_walk")
	await process_frame
	check("a look on the first line turns the view before it is said", [game.view, _box.visible, _calling_line()], [&"Right", false, "Look over there."])
	_calling.call(&"_on_click", _left_click())
	await process_frame
	check("the next line stays in the call-out box", [game.view, _calling_line()], [&"Right", "See it?"])
	_calling.call(&"_on_click", _left_click())
	await process_frame
	check("the choices turn the player back to answer, without saying the line again", [game.view, _box.visible, _calling.visible, _said(), _choices().map(func(b: Button) -> String: return b.text)], [&"Main", true, false, "", ["> Yes."]])
	_main.queue_free()


# Clicks through the box, a line at a time, until it says [param text] ("" for the end of the conversation).
func _click_box_until(text: String) -> void:
	for i: int in 40:
		if (text != "" and (_said() == text or _calling_line() == text)) or (text == "" and game.visitor_state != game.VisitorState.TALKING):
			return
		(_box.get_node("%LineLabel") as TypedLabel).finish()
		_box.call(&"_on_click", _left_click())
		await process_frame
	check("the box reaches \"%s\"" % text, _said(), text)


func _said() -> String:
	var line: DialogueLine = _box.call(&"shown_line")
	return line.text if line != null else ""


func _calling_line() -> String:
	return (_calling.get_node("%Line") as Label).text if _calling.visible else ""


func _choices() -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in _box.get_node("%Choices").get_children():
		if node is Button and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _left_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click

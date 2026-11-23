extends "res://tests/test.gd"
## A conversation that ends in two [leaving] lines: the dialogue box closes before them, and the
## customer calls both out, one after the other, in the call-out box while walking out; once they
## are out of sight the box goes.

const ERRAND := """customer: skater_bro

== drop-off
(neutral) Fix it, dude.
(neutral) Later, skater! [leaving]
(happy) Peace out! [leaving]
"""


func run() -> void:
	var parsed := StoryFormat.parse_errand(ERRAND, "res://story/errands/0101_skater_bro.errand")
	check("the errand parses", parsed.errors, PackedStringArray())
	var errand := parsed.value as Errand
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	game.start_day(make_day(1, [[errand.customer, load("res://problems/dust_overheat.tres"), errand.conversations]]))
	game.open_shop()
	tick(1.0)
	var shop: Node = main.get_node("%Shop")
	await process_frame
	shop.call(&"skip_walk")
	await process_frame
	var box: Control = main.get_node("%DialogueOverlay")
	var calling: Control = main.get_node("%CustomerCalling")
	var said: Label = calling.get_node("%Line")
	check("the customer talks in the box", [game.visitor_state, box.visible, (box.get_node("%LineLabel") as Label).text], [game.VisitorState.TALKING, true, "Fix it, dude."])

	box.get_node("%LineLabel").call(&"finish")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	box.call(&"_on_click", click)
	await process_frame
	check("after the last line in the box, the box closes and the customer walks out", [box.visible, game.visitor_state], [false, game.VisitorState.WALKING_OUT])
	check("the first leaving line is called out at once", [calling.visible, said.text], [true, "Later, skater!"])
	await create_timer(float(calling.get(&"show_seconds")) + float(calling.get(&"leaving_gap")) + 0.1).timeout
	check("then the second, while still walking", [game.visitor_state in [game.VisitorState.WALKING_OUT, game.VisitorState.OUTSIDE], calling.visible, said.text], [true, true, "Peace out!"])
	shop.call(&"skip_walk")
	await process_frame
	check("out of sight, the call-out box goes", [game.visitor_state, calling.visible], [game.VisitorState.NONE, false])
	main.queue_free()

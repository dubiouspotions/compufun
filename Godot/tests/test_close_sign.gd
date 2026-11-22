extends "res://tests/test.gd"
## The Open sign takes clicks and pulses an outline only while the shop can open or close, and the close
## question comes in the game's panel before day 4's warp and in a Win95 message box from it on.


func run() -> void:
	var sign: Node3D = (load("res://props/open_sign.tscn") as PackedScene).instantiate()
	root.add_child(sign)
	var end_of_day: Control = (load("res://ui/end_of_day.tscn") as PackedScene).instantiate()
	root.add_child(end_of_day)
	await process_frame
	var hotspot: Area3D = sign.get_node("%Hotspot")
	var outline: Node3D = sign.get_node("%Outline")
	var day_1: Day = load("res://days/day_1.tres")
	var asked := [0]
	var opened := [0]
	sign.connect("close_requested", func() -> void: asked[0] += 1)
	sign.connect("open_requested", func() -> void: opened[0] += 1)

	check("restore day 1, closed in the morning", game.restore({"day": 1, "phase": "CLOSED"}), "")
	check("openable: clicks and the outline", [game.can_open(), hotspot.input_ray_pickable, outline.visible], [true, true, true])
	hotspot.emit_signal("clicked", hotspot)
	check("a click asks to open, not to close", [opened[0], asked[0]], [1, 0])

	check("restore day 1, one customer still to come", game.restore({"day": 1, "arrivals": day_1.errands.size() - 1}), "")
	check("before the last customer: no clicks, no outline", [game.can_close(), hotspot.input_ray_pickable, outline.visible], [false, false, false])
	check("restore day 1, every customer came and left", game.restore({"day": 1, "arrivals": day_1.errands.size()}), "")
	check("closable: clicks and the outline", [game.can_close(), hotspot.input_ray_pickable, outline.visible], [true, true, true])
	hotspot.emit_signal("clicked", hotspot)
	check("a click asks to close", asked[0], 1)

	var panel: Control = end_of_day.get_node("%Panel")
	var win95: Control = end_of_day.get_node("%Dialog")
	end_of_day.call("ask")
	check("day 1 asks in the panel", [panel.visible, win95.visible], [true, false])
	(end_of_day.get_node("%No") as Button).pressed.emit()
	check("No leaves the shop open", [panel.visible, game.phase], [false, game.Phase.OPEN])
	var day_4: Day = load("res://days/day_4.tres")
	check("restore day 4", game.restore({"day": 4, "arrivals": day_4.errands.size()}), "")
	end_of_day.call("ask")
	check("day 4 asks in a Win95 message box", [panel.visible, win95.visible], [false, true])
	sign.queue_free()
	end_of_day.queue_free()
	await process_frame

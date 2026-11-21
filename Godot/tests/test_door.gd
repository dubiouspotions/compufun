extends "res://tests/test.gd"
## The shop door stands open only while the shop is open, and swings when that changes.


func run() -> void:
	var door: Node3D = (load("res://props/door.tscn") as PackedScene).instantiate()
	door.set("swing_seconds", 0.1)
	check("restore day 1, closed in the morning", game.restore({"day": 1, "phase": "CLOSED"}), "")
	root.add_child(door)
	await process_frame
	var hinge: Node3D = door.get_node("%Hinge")
	var open_angle := deg_to_rad(float(door.get("open_degrees")))
	check("closed morning: shut at once", [door.call("is_open"), hinge.rotation.y], [false, 0.0])

	game.call("open_shop")
	check("the shop opens: the door opens", door.call("is_open"), true)
	await create_timer(0.3).timeout
	check("swung open", is_equal_approx(hinge.rotation.y, open_angle), true)

	check("calling keeps it open", [game.restore({"day": 1, "arrivals": 3, "phase": "CALLING", "calling_slot": 0,
			"jobs": [{"customer": "res://customers/skater_bro.tres", "hardware_fixed": true}]}), door.call("is_open")], ["", true])
	check("restore day 1, every customer came", game.restore({"day": 1, "arrivals": 3}), "")
	game.call("close_shop")
	check("night: the door shuts", door.call("is_open"), false)
	await create_timer(0.3).timeout
	check("swung shut", is_zero_approx(hinge.rotation.y), true)
	check("the end: shut", [game.restore({"day": 7, "phase": "ENDED", "arrivals": 2}), door.call("is_open")], ["", false])
	door.queue_free()
	await process_frame

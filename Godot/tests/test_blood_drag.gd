extends "res://tests/test.gd"
## A computer that slides left off the blood puddle, as the one left of it leaves the counter, drags a
## smear of blood to where it stops; one that slides onto the puddle drags none, and without blood
## there is no smear. A restore shows the smear at once.

const SKATER: String = "res://customers/skater_bro.tres"
const ENTREPRENEUR: String = "res://customers/young_entrepreneur.tres"
const ACCOUNTANT: String = "res://customers/retired_accountant.tres"


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var sign: Node = shop.get_node("CorruptionSigns/BloodPuddle")
	var drag: Node3D = sign.get_node("%Drag")
	var slots: Node = shop.get_node("%JobSlots")

	check("the skater picks up left of the blood", game.restore(_pickup({&"sign_blood_puddle": 2})), "")
	await process_frame
	check("no smear before anything slides", drag.visible, false)
	game.dismiss_visitor(6.0)
	await process_frame
	check("the computer on the puddle slid off it to slot 0: the smear ends there", game.flag(&"blood_puddle_drag"), 1)
	await create_timer(float(slots.get(&"slide_seconds")) * 0.5).timeout
	var halfway := drag.scale.x
	await create_timer(float(slots.get(&"slide_seconds"))).timeout
	check("it reaches out with the slide", [drag.visible, halfway > 0.1 and halfway < 0.9, drag.scale.x], [true, true, 1.0])
	var ends := _left_end(drag)
	var slot_0: Node3D = slots.call(&"slot_marker", 0)
	var offset: Vector3 = sign.get(&"offset")
	check("from the puddle to where the computer stopped", absf(ends - (slot_0.global_position.x + offset.x)) < 0.05, true)

	check("a restore", game.restore(game.snapshot()), "")
	await process_frame
	check("shows the smear at once", [drag.visible, drag.scale.x], [true, 1.0])

	check("the same pickup without blood", game.restore(_pickup({})), "")
	game.dismiss_visitor(6.0)
	await create_timer(1.0).timeout
	check("no smear", [game.flag(&"blood_puddle_drag"), drag.visible], [0, false])

	check("the blood under slot 2: the computer on it slides off", game.restore(_pickup({&"sign_blood_puddle": 3})), "")
	game.dismiss_visitor(6.0)
	await create_timer(1.0).timeout
	check("a smear from slot 2 to slot 1; the one that slid onto it drags none", [game.flag(&"blood_puddle_drag"), drag.visible], [2, true])

	check("the blood under slot 0, which the picked-up computer leaves", game.restore(_pickup({&"sign_blood_puddle": 1})), "")
	game.dismiss_visitor(6.0)
	await create_timer(1.0).timeout
	check("computers that slide onto it drag none", [game.flag(&"blood_puddle_drag"), drag.visible], [0, false])
	shop.queue_free()
	await process_frame


# Day 1: the skater picks up his computer at slot 0; the entrepreneur's and the accountant's stand
# right of it.
func _pickup(flags: Dictionary) -> Dictionary:
	return {"day": 1, "arrivals": 2, "phase": "OPEN", "flags": flags, "visitor": SKATER, "visit": "PICKUP", "visitor_state": "TALKING",
		"jobs": [{"customer": SKATER, "slot": 0, "hardware_fixed": true, "software_fixed": true},
			{"customer": ENTREPRENEUR, "problem": "no_sound", "slot": 1},
			{"customer": ACCOUNTANT, "problem": "no_sound", "slot": 2}]}


# The world x of the smear's far end: the left rim of its leftmost blob.
func _left_end(drag: Node3D) -> float:
	var end := INF
	for blob: MeshInstance3D in drag.get_children():
		end = minf(end, (blob.global_transform * blob.get_aabb()).position.x)
	return end

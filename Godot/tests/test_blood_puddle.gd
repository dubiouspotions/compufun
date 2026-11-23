extends "res://tests/test.gd"
## The blood puddle sign lies at counter slot n - 1 at stage n, settled at once after a jump and
## growing from nothing when set during play; stage 0 takes all of it away.


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var sign: Node = shop.get_node("CorruptionSigns/BloodPuddle")
	var blood: Node3D = sign.get_node("%Blood")
	var floor_puddle: Node3D = sign.get_node("%FloorPuddle")
	var slot_2: Node3D = shop.get_node("%JobSlots").call("slot_marker", 2)

	check("restore at stage 3", game.restore({"day": 7, "phase": "CLOSED", "flags": {"sign_blood_puddle": 3}}), "")
	check("after a jump: at slot 2, settled, the floor puddle full", [blood.visible, blood.global_transform.is_equal_approx(slot_2.global_transform), float(sign.get("_elapsed")) >= float(sign.call("settled_seconds")), floor_puddle.visible, floor_puddle.scale], [true, true, true, true, Vector3.ONE])

	check("restore at stage 0", game.restore({"day": 7, "phase": "CLOSED"}), "")
	check("stage 0: nothing shows, nothing runs", [blood.visible, sign.is_processing()], [false, false])

	game.set_flag(&"sign_blood_puddle", 1)
	await process_frame
	var rivulet: Array = sign.get_node("%Rivulet").get_children().map(func(n: Node3D) -> bool: return n.visible)
	check("set during play: it starts to seep, no rivulet or floor puddle yet", [blood.visible, sign.is_processing(), float(sign.get("_elapsed")) < 1.0, rivulet.has(true), floor_puddle.visible], [true, true, true, false, false])

	check("a restore at the same stage settles it", game.restore(game.snapshot()), "")
	check("settled", float(sign.get("_elapsed")) >= float(sign.call("settled_seconds")), true)
	shop.queue_free()
	await process_frame

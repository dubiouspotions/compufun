extends "res://tests/test.gd"
## The shop door (props/door.gd): shut and locked while the shop is closed (#103); while it is open, a
## customer near the doorway pushes it away from them, in from the street and out from the shop, and
## the closer swings it shut again once nobody is near.


func run() -> void:
	var shop := Node3D.new()
	root.add_child(shop)
	var door: Node3D = (load("res://props/door.tscn") as PackedScene).instantiate()
	shop.add_child(door)
	var walker := Node3D.new()
	walker.add_to_group(&"customer_bodies")
	shop.add_child(walker)
	var doorway := Vector3(0.58, 0.0, 0.0)
	check("restore day 1, closed in the morning", game.restore({"day": 1, "phase": "CLOSED"}), "")
	walker.position = doorway + Vector3(0, 0, -0.6)
	await create_timer(0.6).timeout
	check("closed: someone at the door, still shut", is_zero_approx(door.rotation.y), true)

	game.call("open_shop")
	walker.position = Vector3(5, 0, 5)
	await create_timer(0.6).timeout
	check("open, nobody near: shut", absf(door.rotation.y) < deg_to_rad(2.0), true)
	walker.position = doorway + Vector3(0, 0, -0.6)
	await create_timer(0.6).timeout
	check("pushed from the street: swings into the shop", door.rotation.y < -deg_to_rad(60.0), true)
	walker.position = Vector3(5, 0, 5)
	await create_timer(3.0).timeout
	check("nobody near: the closer shuts it", absf(door.rotation.y) < deg_to_rad(4.0), true)
	walker.position = doorway + Vector3(0, 0, 0.6)
	await create_timer(0.6).timeout
	check("pushed from the shop: swings out to the street", door.rotation.y > deg_to_rad(60.0), true)

	walker.position = Vector3(5, 0, 5)
	await create_timer(3.0).timeout
	check("restore day 1, every customer came", game.restore({"day": 1, "arrivals": 3}), "")
	game.call("close_shop")
	walker.position = doorway + Vector3(0, 0, -0.6)
	await create_timer(0.6).timeout
	check("night: locked, shut", absf(door.rotation.y) < deg_to_rad(4.0), true)
	shop.queue_free()
	await process_frame

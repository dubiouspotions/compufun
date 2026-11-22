extends "res://tests/test.gd"
## The shop door (props/door.gd): shut and locked while the shop is closed (#103); while it is open, a
## customer near the doorway pushes it away from them, in from the street and out from the shop, and
## the closer swings it shut again once nobody is near. Closing the shop slams it, with a sound.


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

	walker.position = Vector3(5, 0, 5)
	game.call("open_shop")
	await create_timer(0.05).timeout  # process_frame comes before the frame's _process
	check("no slam on opening", _slams(door), 0)
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
	await create_timer(0.05).timeout  # process_frame comes before the frame's _process
	check("closing the shop slams it once", _slams(door), 1)
	walker.position = doorway + Vector3(0, 0, -0.6)
	await create_timer(0.6).timeout
	check("night: locked, shut", absf(door.rotation.y) < deg_to_rad(4.0), true)
	shop.queue_free()
	await process_frame


# The slams that play now: SoundSet.play_at adds a player under the door for each.
func _slams(door: Node3D) -> int:
	var slam: SoundSet = door.get("slam")
	return door.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D and n.stream in slam.sounds).size()

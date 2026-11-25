extends "res://tests/test.gd"
## The part boxes in the storage room take clicks only in the storage room: from the shop, a click
## on its wall would reach them through it.


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var camera: Camera3D = shop.get_viewport().get_camera_3d()
	var boxes: Array[Hotspot] = []
	for node: Node in shop.find_children("*", "Area3D"):
		if node is Hotspot and (node as Hotspot).action == Hotspot.Action.TAKE_PART:
			boxes.append(node)
	check("the storage room has part boxes", boxes.is_empty(), false)
	for view: StringName in [&"Left", &"Main", &"Storage"]:
		check("restore " + view, game.restore({"day": 1, "phase": "OPEN", "view": String(view)}), "")
		await create_timer(1.0).timeout  # the camera's turn
		await physics_frame
		var reached := 0
		for box: Hotspot in boxes:
			if camera.is_position_behind(box.global_position):
				continue
			if shop.hotspot_at(camera.unproject_position(box.global_position)) == box:
				reached += 1
		if view == &"Storage":
			check("in the storage room a click reaches a part box", reached > 0, true)
		else:
			check("no click in the %s view reaches a part box" % view, reached, 0)

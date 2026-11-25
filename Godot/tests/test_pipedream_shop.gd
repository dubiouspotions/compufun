extends "res://tests/test.gd"
## The Pipedream in the shop: its pipes start in the trash can, no segment shows in front of a
## hotspot that the Right or the Main view sees (but the pipes' own way out of the can), and while
## the sign shows, an empty-handed click on the can doesn't look into it, while a part still goes in.


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var pipes: Node3D = shop.get_node("%Pipedream")
	var can: Node3D = shop.get_node("Room/TrashCan")
	var can_box := _box(can.get_node("%Hotspot"))
	var paths: Array = (pipes.get("_pipes") as Array).map(func(pipe: Array) -> Array: return pipe[3])
	var cell: float = pipes.get("cell")
	var starts := paths.map(func(path: Array) -> bool: return can_box.has_point(pipes.global_transform * (Vector3(path[0]) * cell)))
	check("every pipe starts in the trash can", starts, paths.map(func(_path: Array) -> bool: return true))
	check("and grows far", paths.any(func(path: Array) -> bool: return path.size() > 300), true)

	var hotspots: Array[Area3D] = []
	for area: Node in shop.get_node("Room").find_children("*", "Area3D", true, false):
		if area is Hotspot:
			hotspots.append(area)
	for view_name: String in ["Right", "Main"]:
		var camera := Camera3D.new()
		shop.add_child(camera)
		var marker: Node3D = shop.get_node("Views/" + view_name)
		camera.global_transform = marker.global_transform
		camera.fov = marker.get("fov")
		camera.make_current()
		var covered: Array[String] = []
		for path: Array in paths:
			for k: int in range(1, path.size()):
				var middle := pipes.global_transform * ((Vector3(path[k - 1]) + Vector3(path[k])) * 0.5 * cell)
				if absf(middle.x - can_box.get_center().x) < 0.15 and absf(middle.z - can_box.get_center().z) < 0.15:
					continue  # the way straight up out of the can
				for hotspot: Area3D in hotspots:
					if _on_screen(camera, _box(hotspot)) and _in_front(camera, middle, _box(hotspot)):
						covered.append("%s at %s" % [shop.get_path_to(hotspot), middle])
		check("from the %s view, no segment in front of a hotspot" % view_name, covered.slice(0, 3), [])
		camera.queue_free()

	var hotspot: Node = can.get_node("%Hotspot")
	game.set_flag(&"sign_pipedream", 1)
	check("the sign takes the look into the can away", can.get("looks_in"), false)
	game.go_to_view(&"Right")
	hotspot.emit_signal(&"clicked", hotspot)
	check("an empty hand: the can takes no click, and the view stays", [hotspot.get("input_ray_pickable"), game.view], [false, &"Right"])
	game.take_new_part(Part.named(&"fan"))
	check("a part in the hand: it takes the click", hotspot.get("input_ray_pickable"), true)
	var thrown: int = game.trashed.size()
	hotspot.emit_signal(&"clicked", hotspot)
	check("and throws the part in", [game.hand, game.trashed.size()], [null, thrown + 1])
	game.set_flag(&"sign_pipedream", 0)
	hotspot.emit_signal(&"clicked", hotspot)
	check("the sign off: an empty hand looks into the can again", game.view, &"Trash")
	shop.queue_free()
	await process_frame


func _box(hotspot: Node) -> AABB:
	var size: Vector3 = hotspot.get("size")
	return (hotspot as Node3D).global_transform * AABB(-size * 0.5, size)


# True when [param point] shows on [param camera]'s screen inside [param box]'s outline, nearer than
# its far side.
func _in_front(camera: Camera3D, point: Vector3, box: AABB) -> bool:
	if camera.is_position_behind(point):
		return false
	var rect := Rect2()
	var far := 0.0
	for i: int in 8:
		var corner := box.get_endpoint(i)
		if camera.is_position_behind(corner):
			return false
		var at := camera.unproject_position(corner)
		rect = Rect2(at, Vector2.ZERO) if i == 0 else rect.expand(at)
		far = maxf(far, camera.global_position.distance_to(corner))
	return rect.has_point(camera.unproject_position(point)) and camera.global_position.distance_to(point) < far


func _on_screen(camera: Camera3D, box: AABB) -> bool:
	for i: int in 8:
		if camera.is_position_in_frustum(box.get_endpoint(i)):
			return true
	return false

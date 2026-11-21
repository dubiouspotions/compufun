extends "res://tests/test.gd"


func run() -> void:
	var bench: Node3D = (load("res://rooms/shop/bench.tscn") as PackedScene).instantiate()
	root.add_child(bench)
	var socket := Marker3D.new()
	socket.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.9, 0.17, -0.2))
	root.add_child(socket)
	await process_frame
	bench.lay_cable(socket)
	await physics_frame
	await physics_frame

	var cable: Path3D = bench.get_node("%Cable")
	var length := cable.curve.get_baked_length()
	var plug_hotspot: Node = bench.get_node("%PlugHotspot")
	var missed: Array[float] = []
	for along: float in [0.4, 0.5, 0.6]:
		var point := cable.global_transform * cable.curve.sample_baked(length * along)
		var ahead := cable.global_transform * cable.curve.sample_baked(length * along + 0.01)
		var beside := (ahead - point).cross(Vector3.UP).normalized() * 0.02
		if _hit_from_above(bench, point + beside) != plug_hotspot or _hit_from_above(bench, point - beside) != plug_hotspot:
			missed.append(along)
	check("the connected cord takes the plug's clicks 2 cm either side of its middle (missed at these fractions)", missed, [] as Array[float])

	bench.lay_cable(null)
	await physics_frame
	await physics_frame
	var plug_body: Node3D = bench.get_node("%Plug/Body")
	check("the resting plug takes clicks", _hit_from_above(bench, plug_body.global_position), plug_hotspot)
	bench.queue_free()
	socket.queue_free()
	await _check_rest_in_main_view()


# In the shop's Main view, the resting plug lies in sight and takes the clicks around it, and the
# monitor and the computer in slot 0 still take theirs.
func _check_rest_in_main_view() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	check("restore a job in slot 0, unplugged", game.restore({"jobs": [{"customer": "res://customers/skater_bro.tres",
		"problem": "dust_overheat", "slot": 0}], "connected_slot": -1, "view": "Main"}), "")
	for i in 3:
		await physics_frame
	var bench: Node3D = shop.find_child("Bench", true, false)
	var eye: Vector3 = (shop.get_node("%Camera") as Camera3D).global_position
	var plug_body: Node3D = bench.get_node("%Plug/Body")
	var plug_hotspot: Node = bench.get_node("%PlugHotspot")
	var missed: Array[Vector3] = []
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.03, 0.0, 0.0), Vector3(-0.03, 0.0, 0.0), Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.0, 0.03)]:
		if _hit_from(shop, eye, plug_body.global_position + offset) != plug_hotspot:
			missed.append(offset)
	check("the Main view sees the resting plug and 3 cm around it (missed at these offsets)", missed, [] as Array[Vector3])
	var screen: Node = bench.get_node("%ScreenHotspot")
	check("the Main view clicks the bench screen", _hit_from(shop, eye, screen.global_position), screen)
	var computer: Node = shop.find_child("Slot0", true, false).find_child("Hotspot", true, false)
	check("the Main view clicks the computer in slot 0", _hit_from(shop, eye, computer.global_position), computer)
	shop.queue_free()


func _hit_from_above(bench: Node3D, point: Vector3) -> Object:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 0.1)
	query.collide_with_areas = true
	return bench.get_world_3d().direct_space_state.intersect_ray(query).get("collider")


# The first pickable collider on the ray from [param eye] through [param point], as the mouse picks.
func _hit_from(scene: Node3D, eye: Vector3, point: Vector3) -> Object:
	var query := PhysicsRayQueryParameters3D.create(eye, eye + (point - eye) * 2.0)
	query.collide_with_areas = true
	while true:
		var hit := scene.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.collider as CollisionObject3D).input_ray_pickable:
			return hit.get("collider")
		query.exclude += [hit.rid]
	return null

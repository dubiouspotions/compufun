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


func _hit_from_above(bench: Node3D, point: Vector3) -> Object:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 0.1)
	query.collide_with_areas = true
	return bench.get_world_3d().direct_space_state.intersect_ray(query).get("collider")

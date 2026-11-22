extends "res://tests/test.gd"
## A customer's footsteps sound of the ground under them: asphalt where the path starts in the
## alley, the sidewalk on the porch at the door, and tiles at the counter where it ends.


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var path: Path3D = shop.get_node("CustomerPath")
	var start := path.to_global(path.curve.get_point_position(0))
	var end := path.to_global(path.curve.get_point_position(path.curve.point_count - 1))
	var porch: Node3D = shop.get_node("%Outside/Porch")
	check("the path starts on asphalt", _steps_at(start), "res://sounds/footsteps_asphalt.tres")
	check("the porch is sidewalk", _steps_at(porch.global_position + Vector3(0.9, 0, 0.3)),
			"res://sounds/footsteps_sidewalk.tres")
	check("the path ends on the shop's tiles", _steps_at(end), "res://sounds/footsteps.tres")
	check("no ground far away", Ground.under(Vector3(500, 0, 500), self), null)
	shop.queue_free()
	await process_frame


func _steps_at(point: Vector3) -> String:
	var ground := Ground.under(point, self)
	return ground.steps.resource_path if ground != null and ground.steps != null else "none at %s" % point

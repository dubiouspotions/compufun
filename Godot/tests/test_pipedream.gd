extends "res://tests/test.gd"


func run() -> void:
	var scene: PackedScene = load("res://rooms/shop/pipedream.tscn")
	var pipes: Node3D = scene.instantiate()
	var twin: Node3D = scene.instantiate()
	root.add_child(pipes)
	root.add_child(twin)
	await process_frame

	check("no pipes on day 2", pipes.amount(_warp(2)), 0.0)
	check("pipes from day 3", pipes.amount(_warp(3)) > 0.0, true)
	check("more each day", pipes.amount(_warp(4)) > pipes.amount(_warp(3)), true)
	check("all pipes on day 7", pipes.amount(_warp(7)), 1.0)

	pipes.warp = _warp(7)
	pipes.call("_process", 1000.0)
	var all: int = pipes.shown_segments()
	check("day 7 grows many segments", all > 100, true)
	pipes.warp = _warp(3)
	pipes.call("_process", 1000.0)
	var day_3: int = pipes.shown_segments()
	check("day 3 shows a part", day_3 > 0 and day_3 < all, true)

	twin.warp = _warp(3)
	twin.call("_process", 1000.0)
	check("the same seed grows the same pipes", twin.shown_segments(), day_3)
	var a: MultiMesh = (pipes.get_child(0) as MultiMeshInstance3D).multimesh
	var b: MultiMesh = (twin.get_child(0) as MultiMeshInstance3D).multimesh
	check("in the same places", a.get_instance_transform(a.instance_count - 1), b.get_instance_transform(b.instance_count - 1))

	pipes.warp = _warp(2)
	pipes.call("_process", 1000.0)
	check("a jump back to day 2 hides them", pipes.shown_segments(), 0)


func _warp(number: int) -> float:
	return (load("res://days/day_%d.tres" % number) as Day).warp

extends "res://tests/test.gd"


func run() -> void:
	var scene: PackedScene = load("res://rooms/shop/pipedream.tscn")
	var pipes: Node3D = scene.instantiate()
	var twin: Node3D = scene.instantiate()
	root.add_child(pipes)
	root.add_child(twin)
	await process_frame

	check("the sign's first amount before day 3", pipes.amount(_warp(2)), pipes.first_amount)
	check("more each day", pipes.amount(_warp(4)) > pipes.amount(_warp(3)), true)
	check("all pipes on day 7", pipes.amount(_warp(7)), 1.0)

	pipes.warp = _warp(7)
	pipes.call("_process", 1000.0)
	check("no pipes while the sign is off", pipes.shown_segments(), 0)
	pipes.stage = 1
	pipes.call("_process", 1000.0)
	var all: int = pipes.shown_segments()
	check("day 7 grows many segments", all > 100, true)
	pipes.warp = _warp(3)
	pipes.call("_process", 1000.0)
	var day_3: int = pipes.shown_segments()
	check("day 3 shows a part", day_3 > 0 and day_3 < all, true)
	pipes.stage = 2
	pipes.call("_process", 1000.0)
	check("stage 2 spreads to all of them on day 3", pipes.shown_segments(), all)
	pipes.stage = 1

	twin.stage = 1
	twin.warp = _warp(3)
	twin.call("_process", 1000.0)
	check("the same seed grows the same pipes", twin.shown_segments(), day_3)
	var a: MultiMesh = (pipes.get_child(0) as MultiMeshInstance3D).multimesh
	var b: MultiMesh = (twin.get_child(0) as MultiMeshInstance3D).multimesh
	check("in the same places", a.get_instance_transform(a.instance_count - 1), b.get_instance_transform(b.instance_count - 1))

	pipes.stage = 0
	check("the sign off takes them away at once", pipes.shown_segments(), 0)

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	camera.look_at_from_position(pipes.global_position + Vector3(0.5, 0.5, 2.0), pipes.global_position + Vector3(0.5, 0.5, -1.0))
	pipes.stage = 1
	pipes.call("_process", 1000.0)
	check("no growth while the camera looks at them", pipes.shown_segments(), 0)
	camera.look_at_from_position(pipes.global_position + Vector3(0.5, 0.5, 2.0), pipes.global_position + Vector3(0.5, 0.5, 5.0))
	pipes.call("_process", 1000.0)
	check("they grow once it looks away", pipes.shown_segments(), day_3)

func _warp(number: int) -> float:
	return game.day_of(number).warp

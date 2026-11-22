extends "res://tests/test.gd"
## On the mat in front of the open computer, no part lies on the screwdriver's dashed outline, and the
## mat takes no click there: every part on every mat spot, and both halves of the mat, stay beside it.


func run() -> void:
	var pierre: Customer = load("res://customers/skater_bro.tres")
	game.start_day(make_day(1, [[pierre, load("res://problems/dust_overheat.tres")]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	var computer: Node3D = (load("res://rooms/shop/job_computer.tscn") as PackedScene).instantiate()  # untyped: JobComputer needs the Game autoload to compile
	computer.set(&"job", job)
	root.add_child(computer)
	await process_frame
	game.focus_job(job)
	game.go_to_view(&"Workview")
	game.lay_down(job)
	var open_case := computer.get_node("%OpenCase") as Node3D
	var outline := computer.get_node("%ScrewdriverOutline") as Sprite3D
	var half := outline.texture.get_size() * outline.pixel_size / 2.0
	var centre := open_case.to_local(outline.global_position)
	var outline_rect := Rect2(centre.x - half.x, centre.z - half.y, half.x * 2.0, half.y * 2.0)

	var surfaces: Array[Node] = open_case.get_node("%MatSurfaces").get_children()
	check("the mat has two halves", surfaces.size(), 2)
	for surface: Hotspot in surfaces:
		var at := open_case.to_local(surface.global_position)
		var rect := Rect2(at.x - surface.size.x / 2.0, at.z - surface.size.z / 2.0, surface.size.x, surface.size.z)
		check("%s of the mat is off the outline" % surface.name, rect.intersects(outline_rect), false)

	var on_outline: Array[String] = []
	for spot: Node3D in open_case.get_node("%Spots").get_children():
		for name: String in ["cpu", "fan", "gpu", "hard_drive", "ram"]:
			var model := ((load("res://parts/%s.tres" % name) as Part).model as PackedScene).instantiate() as Node3D
			spot.add_child(model)
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				var box := open_case.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
				if Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersects(outline_rect):
					on_outline.append("%s on %s" % [name, spot.name])
			model.free()
	check("no part on a mat spot lies on the outline", on_outline, [] as Array[String])
	computer.queue_free()
	await process_frame

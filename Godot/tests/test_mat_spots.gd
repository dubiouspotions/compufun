extends "res://tests/test.gd"
## On the mat in front of the open computer, no part lies on the screwdriver's dashed outline or in the
## next computer's slot, and the mat takes no click on the outline: the pieces on its piles, and both
## halves of the mat, stay beside it.


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

	var slots: Node3D = (load("res://rooms/shop/job_slots.tscn") as PackedScene).instantiate()
	var half_slot := absf((slots.get_node("%Slots/Slot1") as Node3D).position.x - (slots.get_node("%Slots/Slot0") as Node3D).position.x) / 2.0
	slots.free()
	for name: String in ["cpu", "fan", "gpu", "hard_drive", "ram", "gpu"]:
		game.take_new_part(load("res://parts/%s.tres" % name))
		game.put_on_mat(job)
	await process_frame
	var off: Array[String] = []
	var shown := 0
	for model: Node in open_case.get_node("%Spots").find_children("*", "Node3D", true, false):
		if not model.has_meta(&"piece"):
			continue
		shown += 1
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var box := open_case.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			if Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersects(outline_rect):
				off.append("%s on the outline" % (model.get_meta(&"piece") as Piece).part.id())
			if box.position.x < -half_slot or box.end.x > half_slot:
				off.append("%s in the next slot" % (model.get_meta(&"piece") as Piece).part.id())
	check("six pieces show on the mat", shown, 6)
	check("every piece on the mat lies off the outline and within its slot", off, [] as Array[String])
	computer.queue_free()
	await process_frame

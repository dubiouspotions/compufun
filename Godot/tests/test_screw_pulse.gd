extends "res://tests/test.gd"
## A lying computer's panel screws each beat a ring while the player can turn them, not under the
## mouse. An empty screw hole shows dark and beats the ring too.


func run() -> void:
	var pierre: Customer = load("res://customers/skater_bro.tres")
	game.start_day(make_day(1, [[pierre, load("res://problems/dust_overheat.tres")]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	var case: Node3D = (load("res://rooms/shop/open_case.tscn") as PackedScene).instantiate()  # untyped: OpenCase needs the Game autoload to compile
	root.add_child(case)
	await process_frame
	case.set(&"job", job)
	var rings: Array[Node3D] = []
	var hotspots: Array[Hotspot] = []
	var holes: Array[Node3D] = []
	for marker: Node in case.find_child("PanelScrews").get_children():
		holes.append(marker.get_node("Hole"))
		for child: Node in marker.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is QuadMesh:
				rings.append(child)
			elif child is Hotspot:
				hotspots.append(child)
	check("a ring and a hotspot per screw", [rings.size(), hotspots.size()], [Job.PANEL_SCREWS, Job.PANEL_SCREWS])
	if rings.size() != Job.PANEL_SCREWS or hotspots.size() != Job.PANEL_SCREWS:
		return
	var shown := func() -> Array: return rings.map(func(r: Node3D) -> bool: return r.visible)
	var dark := func() -> Array: return holes.map(func(h: Node3D) -> bool: return h.visible)

	check("standing, inactive: no rings", shown.call(), [false, false])
	game.focus_job(job)
	game.go_to_view(&"Workview")
	game.lay_down(job)
	case.set(&"active", true)
	check("lying, screwed: both rings", shown.call(), [true, true])
	check("and no holes", dark.call(), [false, false])
	hotspots[1].mouse_entered.emit()
	check("the screw under the mouse shows the hover look instead", shown.call(), [true, false])
	hotspots[1].mouse_exited.emit()
	game.turn_screw(job, 0)
	check("a screw out keeps its ring", shown.call(), [true, true])
	check("and shows its hole", dark.call(), [true, false])
	case.set(&"active", false)
	check("inactive: no rings", shown.call(), [false, false])

extends "res://tests/test.gd"
## Repairs Hardware Puzzle (Hat Guy, day 5) through the Game API: his pieces lie on the wrong places,
## the CPU is missing, the computer won't start. No piece blocks another: each lifts straight into its
## own place, also under a piece that lies there and the fan before the CPU, until only the CPU's place
## shows its ghost; a new CPU from the storage fixes it. Also a snapshot, a restore, and the open
## case's models and ghosts.

func run() -> void:
	var puzzle: Problem = load("res://problems/hardware_puzzle.tres")
	var cpu := Part.named(&"cpu")
	var fan := Part.named(&"fan")
	var board := Part.named(&"motherboard")
	var drive := Part.named(&"hard_drive")
	var hat_guy: Errand = game.day_of(5).alternatives("0501")[0]
	check("Hat Guy brings Hardware Puzzle on day 5", hat_guy.problem, puzzle)
	check("the CPU is missing", puzzle.missing_part, cpu)

	game.start_day(make_day(5, [[hat_guy.customer, puzzle]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	check("only the motherboard is in its place", job.places.keys(), [board])
	check("five pieces lie on wrong places", job.misplaced.size(), 5)
	check("the hard drive lies on the CPU socket", job.misplaced[cpu].part, drive)
	check("not fixed at drop-off", job.hardware_fixed, false)
	check("it switches on, but without a CPU nothing starts", [game.can_power_on(job), job.post_fault()], [true, Job.Fault.NO_CPU])

	game.focus_job(job)
	game.go_to_view(&"Workview")
	game.lay_down(job)
	check("closed: nothing lifts", game.take_misplaced(job, cpu), false)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	var case: Node3D = (load("res://rooms/shop/open_case.tscn") as PackedScene).instantiate()
	case.set(&"job", job)
	case.set(&"active", true)
	root.add_child(case)
	await process_frame
	game.open_case(job, true)
	await process_frame
	var dropping := case.find_children("*", "RigidBody3D", true, false)
	check("the panel comes off: the five misplaced pieces drop, and none can be taken yet", [dropping.size(), _lying_models(case)], [5, 0])
	for i: int in ceili(case.get(&"drop_seconds") * FPS) + 5:
		await physics_frame
	check("then they freeze where they landed, near where they lie", dropping.map(func(b: RigidBody3D) -> bool: return b.freeze), [true, true, true, true, true])
	check("the open case shows the five misplaced pieces", _lying_models(case), 5)

	check("every empty place shows a faint ghost of what belongs there", _ghosts(case), {"cpu": "empty", "fan": "empty", "ram_1": "empty", "ram_2": "empty", "gpu": "empty", "hard_drive": "empty"})
	check("the motherboard can't come out from under them", game.take_part(job, board), false)
	var refused := [0]
	game.hand_refused.connect(func() -> void: refused[0] += 1)
	check("the hard drive lifts off the socket", [game.take_misplaced(job, cpu), game.hand.part, job.misplaced.has(cpu)], [true, drive, false])
	check("its own place shows the ghost to put it in", _ghosts(case)["hard_drive"], "usable")
	_lying_hotspot(case, Part.named(&"ram_1")).clicked.emit(null)
	check("a click on a piece lying where the hand's can't go shakes the hand", [refused[0], game.hand.part], [1, drive])
	check("the drive goes in under the RAM that lies in its bay", [game.put_part(job), job.piece(drive) != null, job.misplaced.has(drive)], [true, true, true])
	check("and the RAM rests on top of it", _lying_rest(case, drive) == _shown(case, drive), true)
	check("the fan lifts off RAM slot 2 and goes in before the missing CPU", [game.take_misplaced(job, Part.named(&"ram_2")), game.put_part(job, fan)], [true, true])

	var saved: Dictionary = game.snapshot()
	check("the snapshot names the misplaced pieces, also one on a filled place", saved["jobs"][0]["misplaced"], {"ram_1": "gpu", "gpu": "ram", "hard_drive": "ram"})
	check("restore", game.restore(saved), "")
	job = game.jobs[0]
	check("restored where they lie", [job.misplaced_data(), job.piece(drive) != null, job.piece(fan) != null], [{"ram_1": "gpu", "gpu": "ram", "hard_drive": "ram"}, true, true])
	var wrong: Dictionary = saved.duplicate(true)
	wrong["jobs"][0]["misplaced"] = {"ram_1": "ram"}
	check("a piece on its own kind of place: refused", game.restore(wrong).contains("can't lie misplaced on ram_1"), true)
	check("the good snapshot restores again", game.restore(saved), "")
	job = game.jobs[0]
	case.set(&"job", job)

	var gpu := Part.named(&"gpu")
	check("the RAM lifts out of the drive bay into a RAM slot", [game.take_misplaced(job, drive), game.put_part(job)], [true, true])
	check("the graphics card lifts off RAM slot 1", game.take_misplaced(job, Part.named(&"ram_1")), true)
	_lying_hotspot(case, gpu).clicked.emit(null)
	check("a click on the RAM that lies in its slot puts it in under that", [game.hand, job.piece(gpu) != null], [null, true])
	check("the last RAM lifts into the other slot", [game.take_misplaced(job, gpu), game.put_part(job)], [true, true])
	var empty := Part.every().filter(func(place: Part) -> bool: return job.piece(place) == null)
	check("nothing lies misplaced; only the CPU's place is empty", [job.misplaced.is_empty(), empty], [true, [cpu]])
	check("and only it shows its ghost", _ghosts(case), {"cpu": "empty"})
	check("a new CPU from the storage goes in under the fan", [game.take_new_part(cpu), game.put_part(job, cpu)], [true, true])
	check("every place filled, nothing misplaced", [job.places.size(), job.misplaced.is_empty()], [7, true])
	check("open: not fixed", job.hardware_fixed, false)
	game.open_case(job, false)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	check("closed and screwed: fixed", job.hardware_fixed, true)
	check("it starts", [game.can_power_on(job), job.post_fault()], [true, Job.Fault.NONE])

	job.hardware_fixed = false
	check("breaking it again lays the pieces wrong again", [job.misplaced.size(), job.piece(cpu)], [5, null])
	case.queue_free()


# Each place with a ghost in the open case, to "usable" (where the hand's piece goes) or "empty".
func _ghosts(case: Node3D) -> Dictionary:
	var found := {}
	for ghost: Node3D in case.get(&"_ghosts"):
		var mesh: MeshInstance3D = ghost.find_children("*", "MeshInstance3D", true, false)[0]
		if ghost.get_parent().get_parent() == case.get(&"_places"):
			found[String(ghost.get_parent().name)] = "empty" if mesh.material_override == case.get(&"_ghost_empty") else "usable"
	return found


# The hotspot of the piece that lies misplaced on [param place].
func _lying_hotspot(case: Node3D, place: Part) -> Hotspot:
	return (case.get(&"_lying") as Dictionary)[game.jobs[0].misplaced[place]][1]


# The model that the piece lying misplaced on [param place] rests on.
func _lying_rest(case: Node3D, place: Part) -> Node3D:
	return (case.get(&"_lying") as Dictionary)[game.jobs[0].misplaced[place]][2]


func _shown(case: Node3D, place: Part) -> Node3D:
	return (case.get(&"_shown") as Dictionary).get(place.id())


func _lying_models(case: Node3D) -> int:
	return case.find_children("*", "Area3D", true, false).filter(func(h: Area3D) -> bool: return h.get_parent().has_meta(&"piece") and h.input_ray_pickable).size()

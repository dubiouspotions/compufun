extends "res://tests/test.gd"
## Repairs Hardware Puzzle (Hat Guy, day 5) through the Game API: his pieces lie on the wrong places,
## the CPU is missing, the computer won't start; lifting each piece into its own place and a new CPU
## from the storage fix it. Also a snapshot, a restore, and the open case's models.

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

	check("a new CPU won't go under the hard drive", [game.take_new_part(cpu), game.put_part(job, cpu)], [true, false])
	game.return_part(cpu)
	check("the motherboard can't come out from under them", game.take_part(job, board), false)
	check("the hard drive lifts off the socket", [game.take_misplaced(job, cpu), game.hand.part, job.misplaced.has(cpu)], [true, drive, false])
	check("one piece in the hand", game.take_misplaced(job, Part.named(&"ram_1")), false)
	check("RAM lies in the drive bay: the drive goes nowhere yet", game.put_part(job), false)
	check("the trash holds it meanwhile", game.trash_part(), true)
	await process_frame
	check("the open case shows four", _lying_models(case), 4)
	check("a new CPU goes in the empty socket", [game.take_new_part(cpu), game.put_part(job, cpu)], [true, true])
	check("the fan lifts off RAM slot 2 onto the CPU", [game.take_misplaced(job, Part.named(&"ram_2")), game.put_part(job, fan)], [true, true])
	check("the RAM lifts out of the drive bay into slot 2", [game.take_misplaced(job, drive), game.put_part(job)], [true, true])
	check("the drive comes back from the trash into its bay", [game.take_from_trash(), game.put_part(job, drive)], [true, true])

	var saved: Dictionary = game.snapshot()
	check("the snapshot names the misplaced pieces", saved["jobs"][0]["misplaced"], {"ram_1": "gpu", "gpu": "ram"})
	check("restore", game.restore(saved), "")
	job = game.jobs[0]
	check("restored where they lie", job.misplaced_data(), {"ram_1": "gpu", "gpu": "ram"})
	var wrong: Dictionary = saved.duplicate(true)
	wrong["jobs"][0]["misplaced"] = {"cpu": "ram"}
	check("a piece on a filled place: refused", game.restore(wrong).contains("can't lie misplaced on cpu"), true)
	wrong["jobs"][0]["misplaced"] = {"ram_1": "ram"}
	check("a piece on its own kind of place: refused", game.restore(wrong).contains("can't lie misplaced on ram_1"), true)
	check("the good snapshot restores again", game.restore(saved), "")
	job = game.jobs[0]
	case.set(&"job", job)

	var gpu := Part.named(&"gpu")
	check("the graphics card lifts off RAM slot 1 into the trash", [game.take_misplaced(job, Part.named(&"ram_1")), game.put_part(job), game.trash_part()], [true, false, true])
	check("the RAM lifts out of the GPU slot into slot 1", [game.take_misplaced(job, gpu), game.put_part(job)], [true, true])
	check("the graphics card from the trash into its slot", [game.take_from_trash(), game.put_part(job, gpu)], [true, true])
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


func _lying_models(case: Node3D) -> int:
	return case.find_children("*", "Area3D", true, false).filter(func(h: Area3D) -> bool: return h.get_parent().has_meta(&"piece") and h.input_ray_pickable).size()

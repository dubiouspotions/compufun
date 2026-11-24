extends "res://tests/test.gd"
## Organ Failure: Skater Bro's organs stand in for his computer's parts. It works as he brings it,
## bleeds onto the counter, and the player may swap the organs for real parts; the problem's flag
## says whether they did.

const ORGANS := {&"motherboard": &"heart", &"cpu": &"spleen", &"fan": &"lungs", &"ram_1": &"kidney_left", &"ram_2": &"kidney_right", &"gpu": &"liver", &"hard_drive": &"brain"}
const REPLACED := &"skater_organs_replaced"


func run() -> void:
	var organs: Problem = load("res://problems/organ_failure.tres")
	var heart := Part.named(&"heart")
	var board := Part.named(&"motherboard")
	check("CompuFunDB leaves it out", organs.in_compufun_db, false)
	check("the heart poses as the motherboard and beats", [heart.poses_as, heart.sound != null, heart.fits(board), heart.fits(Part.named(&"cpu"))], [board, true, true, false])

	# He sets it down in slot 1, beside another computer: the blood seeps out under slot 1.
	var bro: Customer = load("res://customers/skater_bro.tres")
	var other: Customer = load("res://customers/hat_guy.tres")
	game.start_day(make_day(7, [[other, load("res://problems/dust_overheat.tres")], [bro, organs]]))
	game.open_shop()
	for i: int in 2:
		tick(100.0)
		game.customer_arrived()
		game.dialogue_finished()
		game.customer_left()
	var job: Job = game.jobs.filter(func(j: Job) -> bool: return j.problem == organs)[0]
	check("in slot 1, the puddle under it", [job.slot, game.flag(&"sign_blood_puddle")], [1, 2])
	var inside := {}
	for place: Part in job.places:
		inside[place.id()] = job.places[place].part.id()
	check("an organ in every place", inside, ORGANS)
	check("it works as he brings it: fixed, the memory test passes", [job.hardware_fixed, job.fixed, job.memory_fails(), game.can_power_on(job)], [true, true, false, true])
	check("not replaced", game.flag(REPLACED), 0)

	# The heart beats and the lungs wheeze only while it runs.
	await process_frame  # the root enters the tree
	var computer: Node3D = (load("res://rooms/shop/job_computer.tscn") as PackedScene).instantiate()
	computer.set(&"job", job)
	root.add_child(computer)
	await process_frame
	var beat: Hum = computer.get_node(^"%PartSound")
	var wheeze: Hum = computer.get_node(^"%RunningSound")
	check("off: no heartbeat, no wheeze", [beat.on, wheeze.on], [false, false])
	game.set_powered(job, true)
	computer.set(&"powered", job.powered)
	check("on: the heart beats and the lungs wheeze", [beat.on, beat.stream, wheeze.on, wheeze.stream], [true, heart.sound, true, Part.named(&"lungs").running_sound])
	game.set_powered(job, false)
	computer.set(&"powered", job.powered)
	check("off again: both stop", [beat.on, beat.playing, wheeze.on, wheeze.playing], [false, false, false, false])
	computer.free()
	game.set_tested(job)
	check("tested is done: the player can call him", job.done, true)

	# The organs come out like parts and go in the trash; the flag waits for the last one.
	game.focus_job(job)
	game.go_to_view(&"Workview")
	game.lay_down(job)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	game.open_case(job, true)
	check("open: not fixed, not done", [job.hardware_fixed, job.done], [false, false])
	check("the spleen is under the lungs", game.take_part(job, Part.named(&"cpu")), false)
	var order: Array[StringName] = [&"fan", &"cpu", &"ram_1", &"ram_2", &"gpu", &"hard_drive", &"motherboard"]
	for id: StringName in order:
		check("the %s comes out" % ORGANS[id], [game.take_part(job, Part.named(id)), game.hand.part.id()], [true, ORGANS[id]])
		if id != &"motherboard":
			check("still an organ in it", game.flag(REPLACED), 0)
			game.trash_part()
	check("the last organ out: replaced", game.flag(REPLACED), 1)
	check("the heart goes back where it was", [game.put_part(job), job.piece(board).part, game.flag(REPLACED)], [true, heart, 0])
	check("a restore keeps the heart in", game.restore(game.snapshot()), "")
	job = game.jobs.filter(func(j: Job) -> bool: return j.problem == organs)[0]
	check("restored: the heart, the organs in the trash", [job.piece(board).part, Job.pieces_data(game.trashed).slice(-2)], [heart, ["liver", "brain"]])
	game.take_part(job, board)
	game.trash_part()
	check("the kidneys don't come back out of the RAM boxes", game.return_part(Part.named(&"ram")), false)

	# New parts from the storage: fixed again, and the organs stay replaced.
	order.reverse()
	for id: StringName in order:
		var place := Part.named(id)
		check("a new %s goes in" % id, [game.take_new_part(place.piece_part()), game.put_part(job, place)], [true, true])
	game.open_case(job, false)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	check("closed with real parts: fixed, replaced", [job.hardware_fixed, game.flag(REPLACED)], [true, 1])
	check("the trash holds his organs", Job.pieces_data(game.trashed).slice(-7), ["lungs", "spleen", "kidney_left", "kidney_right", "liver", "brain", "heart"])

	await _nobody_answers()


# He is dead: a call about his computer rings out, organs in or not, and he never comes for it.
func _nobody_answers() -> void:
	for replaced: int in [0, 1]:
		check("restore day 7, his computer done", game.restore({"day": 7, "phase": "OPEN", "arrivals": 3, "flags": {REPLACED: replaced},
				"jobs": [{"errand": "0703_skater_bro", "slot": 0, "hardware_fixed": true, "software_fixed": true, "tested": true}]}), "")
		var job: Job = game.jobs[0]
		check("replaced %d: he doesn't answer" % replaced, [game.can_call(), game.answers(job)], [true, false])
		game.call_customer(job)
		check("replaced %d: the call rings out" % replaced, game.rings_out(), true)
		game.hang_up()
		check("replaced %d: nobody comes, and the phone doesn't call again" % replaced, [game.visitor, job.unanswered, game.can_call()], [null, true, false])
		check("replaced %d: the day can close" % replaced, game.can_close(), true)

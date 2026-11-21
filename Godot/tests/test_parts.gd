extends "res://tests/test.gd"
## Repairs Dust Overheat through the Game API, as the wiki page Hardware Repair says: the case,
## the real order, one piece in the hand, the mat, the storage, the trash, power, and a restore.

const GAME := preload("res://game.gd")


func run() -> void:
	var dust: Problem = load("res://problems/dust_overheat.tres")
	var fan: Part = load("res://parts/fan.tres")
	var cpu: Part = load("res://parts/cpu.tres")
	var board: Part = load("res://parts/motherboard.tres")
	var gpu: Part = load("res://parts/gpu.tres")
	check("Dust Overheat breaks the fan", dust.broken_part, fan)
	check("five parts, in order", Part.every().map(func(p: Part) -> StringName: return p.id()), Part.IDS)

	# Pierre brings Dust Overheat; a customer from a file can be restored.
	var pierre: Customer = load("res://customers/pierre.tres")
	check("Pierre has Dust Overheat", pierre.problem, dust)
	game.start_day(make_day(1, [pierre]))
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	check("a full computer, its fan broken", [job.places.size(), job.piece(fan).broken, job.piece(cpu).broken], [5, true, false])
	check("not fixed yet", job.hardware_fixed, false)

	# The case: closed parts can't move, and a computer that is on doesn't open.
	check("closed: the fan can't come out", game.take_part(job, fan), false)
	game.set_powered(job, true)
	check("on: the case doesn't open", [game.open_case(job, true), job.case_open], [false, false])
	game.set_powered(job, false)
	check("off: the case opens", [game.open_case(job, true), job.case_open], [true, true])
	game.set_powered(job, true)
	check("open: no power", job.powered, false)

	# The real order: the fan sits on the CPU, the CPU and the GPU on the motherboard.
	check("the CPU is under the fan", game.take_part(job, cpu), false)
	check("the motherboard is under the CPU and the GPU", game.take_part(job, board), false)
	check("the fan comes out into the hand", [game.take_part(job, fan), game.hand.part, job.piece(fan)], [true, fan, null])
	check("one piece in the hand", game.take_part(job, gpu), false)
	check("no new part with a full hand", game.take_new_part(fan), false)
	check("the old fan goes in the trash", [game.trash_part(), game.hand], [true, null])
	check("nothing to throw away", game.trash_part(), false)
	check("the CPU comes out now", game.take_part(job, cpu), true)
	check("the CPU goes on the mat", [game.put_on_mat(job), job.mat.size(), game.hand], [true, 1, null])
	game.take_part(job, gpu)
	game.put_on_mat(job)
	check("the motherboard comes out last", game.take_part(job, board), true)
	check("an empty place: no power", game.can_power_on(job), false)
	game.put_on_mat(job)
	game.take_from_mat(job, 0)
	check("the CPU can't go in before the motherboard", game.put_part(job), false)
	game.put_on_mat(job)
	game.take_from_mat(job, 1)  # the mat is now [gpu, cpu]: index 1 after the CPU went back
	check("taken back from the mat: the motherboard", game.hand.part, board)
	check("the motherboard goes in", game.put_part(job), true)
	game.take_from_mat(job, 1)
	check("then the CPU", [game.hand.part, game.put_part(job)], [cpu, true])
	game.take_from_mat(job, 0)
	check("then the GPU", [game.hand.part, game.put_part(job), job.mat.size()], [gpu, true, 0])
	check("a new fan from the storage", [game.take_new_part(fan), game.hand.broken], [true, false])
	check("a piece only fits its own place", game.can_put(job, cpu), false)
	game.put_part(job)
	check("all in, but open: not fixed", job.hardware_fixed, false)
	game.open_case(job, false)
	check("closed: fixed", job.hardware_fixed, true)
	game.set_powered(job, true)
	check("it switches on again", job.powered, true)

	# A snapshot keeps the pieces, the mat, the case and the hand; a restore gives them back.
	game.set_powered(job, false)
	game.open_case(job, true)
	game.take_part(job, fan)
	game.put_on_mat(job)
	game.take_new_part(gpu)
	var saved: Dictionary = game.snapshot()
	check("the snapshot names the pieces", [saved["jobs"][0]["parts"].size(), saved["jobs"][0]["mat"], saved["hand"]], [4, ["fan"], ["gpu"]])
	game.trash_part()
	check("restore", game.restore(saved), "")
	var back: Job = game.jobs[0]
	check("restored", [back.case_open, back.piece(fan), back.mat.size(), game.hand.part], [true, null, 1, gpu])
	saved["jobs"][0]["parts"] = ["fan", "fan"]
	check("two fans in one place: refused", game.restore(saved).contains("two pieces"), true)

	# The debug menu and the presets set hardware_fixed: true repairs, false breaks the part again.
	back.hardware_fixed = true
	check("set fixed", [back.hardware_fixed, back.case_open, back.places.size()], [true, false, 5])
	back.hardware_fixed = false
	check("set broken", back.piece(fan).broken, true)


func make_day(number: int, customers: Array[Customer]) -> Day:
	var d := Day.new()
	d.number = number
	d.customers = customers
	d.gap_seconds = 60.0
	return d

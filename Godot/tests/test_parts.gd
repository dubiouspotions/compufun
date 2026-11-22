extends "res://tests/test.gd"
## Repairs Dust Overheat through the Game API, as the wiki page Hardware Repair says: laying it down,
## the side panel and its screws, the real order, one piece in the hand, the mat, the storage, the
## trash, power, and a restore.

const GAME := preload("res://game.gd")


func run() -> void:
	var dust: Problem = load("res://problems/dust_overheat.tres")
	var fan: Part = load("res://parts/fan.tres")
	var cpu: Part = load("res://parts/cpu.tres")
	var board: Part = load("res://parts/motherboard.tres")
	var gpu: Part = load("res://parts/gpu.tres")
	check("Dust Overheat breaks the fan", dust.broken_part, fan)
	check("seven places, in order", Part.every().map(func(p: Part) -> StringName: return p.id()), Part.IDS)

	# Pierre brings Dust Overheat; a customer from a file can be restored.
	var pierre: Customer = load("res://customers/skater_bro.tres")
	var first: Errand = (load("res://days/day_1.tres") as Day).errands[0]
	check("Pierre comes first on day 1, with Dust Overheat", [first.customer, first.problem], [pierre, dust])
	game.start_day(make_day(1, [[pierre, dust]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	check("a full computer, its fan broken", [job.places.size(), job.piece(fan).broken, job.piece(cpu).broken], [7, true, false])
	check("not fixed yet", job.hardware_fixed, false)
	check("the side panel's screws in", job.panel_screws, [true, true])

	# The computer stands until the player lays it down in the Workview, and lies until stood up.
	game.focus_job(job)
	check("outside the Workview it doesn't lie down", game.lay_down(job), false)
	game.go_to_view(&"Workview")
	check("in the Workview it stands", job.lying, false)
	check("standing: the case doesn't open", game.open_case(job, true), false)
	game.set_powered(job, true)
	check("the screwdriver lays it down and switches it off", [game.lay_down(job), job.lying, job.powered], [true, true, false])
	check("it lies already", game.lay_down(job), false)
	check("it stands up", [game.stand_up(job), job.lying], [true, false])
	game.lay_down(job)
	game.go_to_view(&"Main")
	check("leaving the Workview, it stays down", job.lying, true)

	# The case: closed parts can't move, and a computer that is on doesn't open.
	check("closed: the fan can't come out", game.take_part(job, fan), false)
	game.set_powered(job, true)
	check("on: the case doesn't open", [game.open_case(job, true), job.case_open], [false, false])
	game.set_powered(job, false)
	check("screwed: the panel stays on", game.open_case(job, true), false)
	check("the panel's screws come out", [game.turn_screw(job, 0), game.turn_screw(job, 1), job.panel_screws], [true, true, [false, false]])
	check("off and unscrewed: the case opens", [game.open_case(job, true), job.case_open], [true, true])
	check("open: it doesn't stand up", [game.stand_up(job), job.lying], [false, true])
	check("no panel, no panel screws", game.turn_screw(job, 0), false)
	game.set_powered(job, true)
	check("open: it still runs, for testing", job.powered, true)
	check("running: nothing comes out", game.take_part(job, fan), false)
	game.set_powered(job, false)

	# The real order: the fan sits on the CPU, the CPU and the GPU on the motherboard.
	check("the CPU is under the fan", game.take_part(job, cpu), false)
	check("the motherboard is under the CPU and the GPU", game.take_part(job, board), false)
	check("the fan comes out into the hand", [game.take_part(job, fan), game.hand.part, job.piece(fan)], [true, fan, null])
	check("one piece in the hand", game.take_part(job, gpu), false)
	check("no new part with a full hand", game.take_new_part(fan), false)
	check("the old fan doesn't go in a storage box", game.return_part(fan), false)
	check("the old fan goes in the trash", [game.trash_part(), game.hand], [true, null])
	check("nothing to throw away", game.trash_part(), false)
	check("the CPU comes out now", game.take_part(job, cpu), true)
	check("the CPU goes on the mat", [game.put_on_mat(job), job.mat.size(), game.hand], [true, 1, null])
	check("the GPU comes out freely: only the panel is screwed", game.take_part(job, gpu), true)
	game.put_on_mat(job)
	check("the RAM sits on the motherboard too", game.take_part(job, board), false)
	for slot: Part in [Part.named(&"ram_1"), Part.named(&"ram_2")]:
		game.take_part(job, slot)
		game.put_on_mat(job)
	check("the motherboard comes out last", game.take_part(job, board), true)
	check("an empty place: no power", game.can_power_on(job), false)
	game.put_on_mat(job)  # the mat: [cpu, gpu, ram, ram, motherboard]
	game.take_from_mat(job, 0)
	check("the CPU can't go in before the motherboard", game.put_part(job), false)
	game.put_on_mat(job)  # [gpu, ram, ram, motherboard, cpu]
	game.take_from_mat(job, 3)
	check("taken back from the mat: the motherboard", game.hand.part, board)
	check("the motherboard goes in", game.put_part(job), true)
	game.take_from_mat(job, 3)
	check("then the CPU", [game.hand.part, game.put_part(job)], [cpu, true])
	game.take_from_mat(job, 0)
	check("then the GPU", [game.hand.part, game.put_part(job)], [gpu, true])
	for i in 2:
		game.take_from_mat(job, 0)
		game.put_part(job)
	check("then the RAM, and the mat is empty", [job.piece(Part.named(&"ram_2")) != null, job.mat.size()], [true, 0])
	check("a new fan from the storage", [game.take_new_part(fan), game.hand.broken], [true, false])
	check("not into another part's box", game.return_part(cpu), false)
	check("back into its own box", [game.return_part(fan), game.hand], [true, null])
	game.take_new_part(fan)
	check("a piece only fits its own place", game.can_put(job, cpu), false)
	game.put_part(job)
	check("all in, but open: not fixed", job.hardware_fixed, false)
	game.open_case(job, false)
	check("the panel is on, its screws out: not fixed", job.hardware_fixed, false)
	check("a screw out: it doesn't stand up", game.stand_up(job), false)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	check("closed and screwed: fixed", job.hardware_fixed, true)
	game.set_powered(job, true)
	check("lying: it runs too", job.powered, true)
	game.set_powered(job, false)
	check("closed and screwed: it stands up", [game.stand_up(job), job.lying], [true, false])
	game.set_powered(job, true)
	check("it switches on again", job.powered, true)

	# A snapshot keeps the pieces, the mat, the case and the hand; a restore gives them back.
	game.go_to_view(&"Workview")
	check("laying it down switches it off", [game.lay_down(job), job.powered], [true, false])
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	game.open_case(job, true)
	game.take_part(job, fan)
	check("a fan that was in a computer doesn't go back in its box", game.return_part(fan), false)
	game.put_on_mat(job)
	game.take_new_part(gpu)
	var saved: Dictionary = game.snapshot()
	check("the snapshot names the pieces", [saved["jobs"][0]["parts"].size(), saved["jobs"][0]["mat"], saved["hand"]], [6, ["fan"], ["gpu+"]])
	game.trash_part()
	check("restore", game.restore(saved), "")
	check("a restore keeps it lying", game.jobs[0].lying, true)
	var back: Job = game.jobs[0]
	check("restored", [back.case_open, back.piece(fan), back.mat.size(), game.hand.part, game.hand.unused], [true, null, 1, gpu, true])
	check("the panel's screws restored", back.panel_screws, [false, false])
	saved["jobs"][0]["parts"]["cpu"] = "fan"
	check("a fan in the CPU's place: refused", game.restore(saved).contains("takes cpu, not fan"), true)

	# The debug menu and the presets set hardware_fixed: true repairs, false breaks the part again.
	back.hardware_fixed = true
	check("set fixed", [back.hardware_fixed, back.case_open, back.places.size(), back.panel_screws], [true, false, 7, [true, true]])
	back.hardware_fixed = false
	check("set broken", back.piece(fan).broken, true)

	# A broken fan carries its dust wherever its model shows; a new one is clean.
	var dusty := Piece.new(fan, true).make_model()
	var clean := Piece.new(fan).make_model()
	check("dust on the broken fan only", [dusty.get_node(^"Broken").visible, clean.get_node(^"Broken").visible], [true, false])
	dusty.free()
	clean.free()

extends "res://tests/test.gd"
## Bad RAM: one of the two RAM modules is broken, in a random slot. The memory test at boot is the
## only clue, so the player swaps a module and switches it on, case open, to find out.

const BOOT := "res://win95/boot_sequence.tscn"


func run() -> void:
	var bad_ram: Problem = load("res://problems/bad_ram.tres")
	var ram: Part = load("res://parts/ram.tres")
	var slot_1: Part = load("res://parts/ram_1.tres")
	var slot_2: Part = load("res://parts/ram_2.tres")
	var accountant: Customer = load("res://customers/retired_accountant.tres")
	check("the accountant has bad RAM", accountant.problem, bad_ram)
	check("both slots take RAM", [slot_1.piece_part(), slot_2.piece_part(), ram.fits_computer(), slot_1.fits_computer()], [ram, ram, true, false])

	# The broken module lands in either slot.
	var bad_slots := {}
	for i in 40:
		var each := Job.new(accountant, 0, i)
		var broken: Array = [slot_1, slot_2].filter(func(slot: Part) -> bool: return each.piece(slot).broken)
		check("one module is broken", broken.size(), 1)
		bad_slots[broken[0]] = true
	check("either slot can hold it", bad_slots.size(), 2)

	game.start_day(make_day([accountant]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	var bad: Part = slot_1 if job.piece(slot_1).broken else slot_2
	var good: Part = slot_2 if bad == slot_1 else slot_1
	check("RAM in both slots, the memory test fails", [job.piece(slot_1).part, job.piece(slot_2).part, job.memory_share(), job.memory_fails()], [ram, ram, 1.0, true])

	# Open it, then test it running.
	game.focus_job(job)
	game.go_to_view(&"Workview")
	game.lay_down(job)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	game.open_case(job, true)

	# A wrong guess: the good module out, a new one in. Still failing.
	check("the good module comes out", game.take_part(job, good), true)
	game.trash_part()
	check("one slot empty: it still switches on", game.can_power_on(job), true)
	check("half the memory, still failing", [job.memory_share(), job.memory_fails()], [0.5, true])
	check("a new module", game.take_new_part(ram), true)
	check("it fits the empty slot", [game.put_part(job, good), job.piece(good).broken], [true, false])
	game.set_powered(job, true)
	check("running open", job.powered, true)
	check("running: no module comes out", game.take_part(job, bad), false)
	game.set_powered(job, false)

	# The right guess: the bad one out. Now the test passes.
	check("the bad module comes out", game.take_part(job, bad), true)
	check("it is broken", game.hand.broken, true)
	check("the memory test passes on one module", [job.memory_share(), job.memory_fails()], [0.5, false])
	game.trash_part()
	game.take_new_part(ram)
	check("a new module goes in either free slot", game.put_part(job), true)
	check("not fixed while open", job.hardware_fixed, false)
	game.open_case(job, false)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	check("fixed", [job.hardware_fixed, job.fixed], [true, true])

	# Two empty RAM slots: no power. A snapshot keeps which slot holds the broken module.
	job.hardware_fixed = false
	var saved: Dictionary = game.snapshot()
	var bad_now: String = "ram_1" if job.piece(slot_1).broken else "ram_2"
	check("the snapshot names the place of the broken module", saved["jobs"][0]["parts"][bad_now], "ram!")
	check("restore", game.restore(saved), "")
	check("restored in its place", game.jobs[0].piece(Part.named(StringName(bad_now))).broken, true)
	job = game.jobs[0]
	job.places.erase(slot_1)
	job.places.erase(slot_2)
	check("no RAM: no power", game.can_power_on(job), false)

	# The boot: a broken module halts the memory test; a good one boots on.
	await process_frame  # the root enters the tree
	var failing := await boot(true)
	check("a failing test halts", [failing.contains("Memory test fail"), failing.contains(" OK")], [true, false])
	var passing := await boot(false)
	check("a passing test goes on to Windows", [passing.contains("Starting Windows"), passing.contains("fail")], [true, false])


# Plays the boot with [param fails], and returns the POST's text once it halted or finished.
func boot(fails: bool) -> String:
	var sequence: Node = (load(BOOT) as PackedScene).instantiate()
	sequence.play_on_start = false
	for seconds: StringName in [&"warm_up_seconds", &"memory_test_seconds", &"line_seconds", &"detect_seconds", &"post_hold_seconds", &"verify_seconds", &"starting_seconds", &"splash_seconds"]:
		sequence.set(seconds, 0.0)
	sequence.set(&"memory_fails", fails)
	sequence.set(&"startup_sound", null)
	root.add_child(sequence)
	var post := sequence.get_node("%Post") as RichTextLabel
	var seen := [false, ""]
	sequence.finished.connect(func() -> void: seen.assign([true, post.text]))
	sequence.play()
	for i in 120:
		await process_frame
	check("finished only when the test passes", seen[0], not fails)
	if fails:
		seen[1] = post.text
		sequence.queue_free()
	return seen[1]


func make_day(customers: Array[Customer]) -> Day:
	var d := Day.new()
	d.number = 1
	d.customers = customers
	d.first_wait_seconds = Vector2.ZERO
	d.gap_seconds = Vector2(60.0, 60.0)
	return d

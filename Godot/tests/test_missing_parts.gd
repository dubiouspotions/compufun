extends "res://tests/test.gd"
## A computer that misses a part fails as a real one does: without a motherboard it doesn't switch
## on; without a CPU nothing but the fans starts; without memory or a video card the PC speaker beeps
## its code and the screen gets no picture; without a fan it beeps an alarm and switches itself off;
## without a hard drive the BIOS halts on DISK BOOT FAILURE.

const BOOT := "res://win95/boot_sequence.tscn"


func run() -> void:
	var dust: Problem = load("res://problems/dust_overheat.tres")
	var pierre: Customer = load("res://customers/skater_bro.tres")
	game.start_day(make_day(1, [[pierre, dust]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	await process_frame  # the root enters the tree
	var computer: Node3D = (load("res://rooms/shop/job_computer.tscn") as PackedScene).instantiate()
	computer.set(&"job", job)
	root.add_child(computer)
	await process_frame
	var tower := computer.get_node("Tower")

	check("a whole computer: no fault", job.post_fault(), Job.Fault.NONE)
	for missing: Array in [[[&"motherboard"], false, Job.Fault.NONE], [[&"cpu"], true, Job.Fault.NO_CPU], [[&"ram_1"], true, Job.Fault.NONE],
			[[&"ram_1", &"ram_2"], true, Job.Fault.NO_MEMORY], [[&"gpu"], true, Job.Fault.NO_VIDEO], [[&"cpu", &"gpu"], true, Job.Fault.NO_CPU]]:
		var kept := job.places.duplicate()
		for place_id: StringName in missing[0]:
			job.places.erase(Part.named(place_id))
		check("without %s: switches on %s, fault %s" % [missing[0], missing[1], missing[2]], [game.can_power_on(job), job.post_fault()], [missing[1], missing[2]])
		job.places = kept
	for fault: Array in [[&"cpu", PackedFloat32Array()], [&"gpu", computer.get(&"no_video_beeps")]]:
		var kept := job.places.duplicate()
		job.places.erase(Part.named(fault[0]))
		game.set_powered(job, true)
		computer.set(&"powered", job.powered)
		check("without %s the PC speaker beeps %s" % [fault[0], fault[1]], tower.get(&"beeps"), fault[1])
		game.set_powered(job, false)
		job.places = kept
	computer.set(&"powered", false)
	check("off: silent", tower.get(&"beeps"), PackedFloat32Array())

	# Without a fan the CPU overheats: the alarm, then the computer switches itself off.
	job.places.erase(Part.named(&"fan"))
	game.set_powered(job, true)
	check("no fan: it runs", [job.powered, job.overheats(), game.alarms(job)], [true, true, false])
	tick(game.OVERHEAT_SECONDS - game.ALARM_SECONDS + 0.1)
	computer.set(&"powered", job.powered)
	check("the alarm beeps before it switches off", [job.powered, game.alarms(job), tower.get(&"beeps")], [true, true, computer.get(&"overheat_beeps")])
	tick(game.ALARM_SECONDS)
	computer.set(&"powered", job.powered)
	check("then it switches itself off, and the alarm stops", [job.powered, job.heat_seconds, tower.get(&"beeps")], [false, 0.0, PackedFloat32Array()])
	game.set_powered(job, true)
	check("switched on again, it heats up from cold", [job.powered, game.alarms(job)], [true, false])
	game.set_powered(job, false)
	computer.queue_free()

	# Without a hard drive the BIOS has nothing to start from.
	var hardware := Hardware.new()
	hardware.hard_drive = ""
	var post := await boot(hardware)
	check("no hard drive: the summary lists none, and the BIOS halts", [post.contains("Pri. Master Disk : None"), post.contains("DISK BOOT FAILURE"), post.contains("Starting Windows")], [true, true, false])


# Plays the boot of [param hardware] at full speed and returns the POST's text once it halted; fails
# a check if it finishes instead.
func boot(hardware: Hardware) -> String:
	var sequence: Node = (load(BOOT) as PackedScene).instantiate()
	sequence.play_on_start = false
	for seconds: StringName in [&"warm_up_seconds", &"memory_test_seconds", &"line_seconds", &"detect_seconds", &"post_hold_seconds", &"verify_seconds", &"starting_seconds", &"splash_seconds"]:
		sequence.set(seconds, 0.0)
	sequence.set(&"hardware", hardware)
	sequence.set(&"startup_sound", null)
	root.add_child(sequence)
	var post := sequence.get_node("%Post") as RichTextLabel
	var finished := [false]
	sequence.finished.connect(func() -> void: finished[0] = true)
	sequence.play()
	for i in 120:
		await process_frame
	check("the boot halts", finished[0], false)
	var text := post.text
	sequence.queue_free()
	return text

extends "res://tests/test.gd"
## A software fix lands on a running Windows, which tests it at once: the computer is done without
## a reboot, and CompuFunDB prints no Test step for a software-only problem. A hardware problem still
## ends in the Test step.


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/retired_accountant.tres"), load("res://problems/no_sound.tres"), 0, 0)
	game.jobs = [job] as Array[Job]
	game.set_powered(job, true)
	game.connect_cable(job)
	await process_frame
	var win95: Control = bench._desktops.get(job)
	var state: Node = win95.get_node("%ComputerState")
	(win95.get("_boot") as Node).finished.emit()
	check("muted at the desktop: not fixed", [job.fixed, job.tested], [false, false])
	state.call("set_sound", 50.0, false)
	check("unmuted at the desktop: fixed, tested and done at once", [job.fixed, job.tested, job.done], [true, true, true])
	state.call("set_sound", 50.0, true)
	check("muted again: neither", [job.fixed, job.tested], [false, false])
	bench.queue_free()

	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	root.add_child(db)
	await process_frame
	var software: PackedStringArray = db.call("_fix_page", load("res://problems/no_sound.tres"))
	check("the software fix has no Test step", [software.has("-- Test --"), software[-1].contains(db.get("test_step"))], [false, false])
	var hardware: PackedStringArray = db.call("_fix_page", load("res://problems/dust_overheat.tres"))
	var test := " ".join(hardware.slice(hardware.find("-- Test --") + 1)).replace("[ ]", "")
	check("the hardware fix ends in it", [hardware.has("-- Test --"), " ".join(test.split(" ", false)).ends_with(db.get("test_step"))], [true, true])
	db.queue_free()

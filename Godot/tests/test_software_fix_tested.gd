extends "res://tests/test.gd"
## A software fix lands on a running Windows, which tests it at once: the computer is done without
## a reboot, and CompuFunDB lists no Test step for a software-only problem. A hardware problem still
## ends in the Test step.

## CompuFunDB.Column.FIXES, which a test can't name: CompuFunDB names the Game autoload.
const FIXES: int = 2


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

	check("restore a software and a hardware job", game.restore({"day": 1, "arrivals": 2, "jobs": [
		{"customer": "res://customers/retired_accountant.tres", "problem": "no_sound", "slot": 0, "order": 0},
		{"customer": "res://customers/skater_bro.tres", "problem": "dust_overheat", "slot": 1, "order": 1}]}), "")
	var muted: DbRecord = game.enter_job(game.jobs[0], "Retired accountant: Can't hear sounds")
	game.mark_symptom(muted, "Sound is muted", true)
	var hot: DbRecord = game.enter_job(game.jobs[1], "Skater bro: Windows starts and turns off")
	for symptom: String in ["Hangs and reboots at startup", "Computer overheating"]:
		game.mark_symptom(hot, symptom, true)
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	root.add_child(db)
	await process_frame
	check("the software fix has no Test step", _fixes(db), ["-- Software --", "Unmute"])
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	db.call("_on_key", down)
	var steps := _fixes(db)
	check("the hardware fix ends in it", steps.slice(-2), ["-- Test --", db.get("test_step")])
	db.queue_free()


func _fixes(db: Control) -> Array:
	return db.call("_entries", FIXES).map(func(entry: Dictionary) -> String: return entry.text)

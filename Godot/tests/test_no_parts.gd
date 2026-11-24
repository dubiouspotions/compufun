extends "res://tests/test.gd"
## NO PARTS: on day 7 the hat guy's computer has an empty case and runs anyway. Opening it and
## closing it again fixes the hardware; it stays empty and keeps running. His other visits keep
## their parts.


func run() -> void:
	var no_parts: Problem = load("res://problems/no_parts.tres")
	check("CompuFunDB leaves it out", no_parts.in_compufun_db, false)
	check("his days 3 and 5 keep their parts", game.restore({"day": 5, "jobs": [
		{"errand": "0302_hat_guy", "slot": 0}, {"errand": "0501_hat_guy", "slot": 1}]}), "")
	check("day 3 is whole, day 5 only rearranged (hardware_puzzle)", [game.jobs[0].places.size(), game.jobs[0].runs_empty(), game.jobs[1].misplaced.is_empty(), game.jobs[1].runs_empty()], [7, false, false, false])

	check("restore day 7's errand", game.restore({"day": 7, "jobs": [{"errand": "0701_hat_guy", "slot": 0}]}), "")
	var job: Job = game.jobs[0]
	check("its problem is no_parts, its case empty, not fixed", [job.problem, job.places.size(), job.hardware_fixed, job.done], [no_parts, 0, false, false])
	check("it switches on, and nothing stops the BIOS", [game.can_power_on(job), job.post_fault(), job.memory_share(), job.memory_fails()], [true, Job.Fault.NONE, 1.0, false])
	game.set_powered(job, true)
	check("it runs without a fan, and doesn't heat up", [job.powered, job.overheats()], [true, false])
	game.set_powered(job, false)

	game.focus_job(job)
	game.go_to_view(&"Workview")
	check("it lies down", game.lay_down(job), true)
	for i: int in Job.PANEL_SCREWS:
		game.turn_screw(job, i)
	check("open: empty, not fixed", [game.open_case(job, true), job.places.size(), job.hardware_fixed], [true, 0, false])
	check("closed, screws out: not fixed", [game.open_case(job, false), job.hardware_fixed], [true, false])
	check("a restore keeps that it was opened", game.restore(game.snapshot()), "")
	job = game.jobs[0]
	for i: int in Job.PANEL_SCREWS:
		game.turn_screw(job, i)
	check("closed and screwed: fixed, still empty", [job.hardware_fixed, job.fixed, job.places.size()], [true, true, 0])
	check("it stands up", game.stand_up(job), true)
	game.set_powered(job, true)
	check("it still runs", [job.powered, job.post_fault()], [true, Job.Fault.NONE])
	game.set_tested(job)
	check("tested: the job is done", job.done, true)
	check("a restore keeps it done and empty", game.restore(game.snapshot()), "")
	check("restored", [game.jobs[0].done, game.jobs[0].places.size()], [true, 0])

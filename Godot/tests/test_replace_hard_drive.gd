extends "res://tests/test.gd"
## Replace Hard Drive: the top hat man's drive works and holds his evidence, but he wants it swapped.
## His computer runs as he brings it; the job is fixed only once a new drive is in.


func run() -> void:
	var problem: Problem = load("res://problems/replace_hard_drive.tres")
	var drive := Part.named(&"hard_drive")
	check("restore day 6's errand", game.restore({"day": 6, "jobs": [{"errand": "0602_top_hat_man", "slot": 0}]}), "")
	var job: Job = game.jobs[0]
	check("its problem is replace_hard_drive, its unwanted part the hard drive", [job.problem, problem.unwanted_part, problem.has_repair_mechanics()], [problem, drive, true])
	check("the old drive is in, unwanted and not broken", [job.piece(drive).part, job.piece(drive).unwanted, job.piece(drive).broken], [drive, true, false])
	check("not fixed, not done", [job.hardware_fixed, job.fixed, job.done], [false, false, false])
	check("it boots: nothing stops the BIOS, the memory test passes, Windows doesn't hang", [game.can_power_on(job), job.post_fault(), job.memory_fails(), problem.hangs_after], [true, Job.Fault.NONE, false, 0.0])

	var setup: Win95Setup = game.setup_for(job)
	check("the old drive holds the ledger and the to-do list", [setup.file_at("C:\\My Documents\\LEDGER2.TXT") != null, setup.file_at("C:\\My Documents\\TODO.TXT") != null], [true, true])
	var subjects: Array = setup.emails.map(func(mail: Email) -> String: return mail.subject)
	check("and the mails about the books", ["The second set of books" in subjects, "Re: The second set of books" in subjects, "Questions about the pension fund" in subjects], [true, true, true])

	check("a restore keeps the old drive unwanted", game.restore(game.snapshot()), "")
	job = game.jobs[0]
	check("restored: still the unwanted drive", [Job.pieces_data([job.piece(drive)]), job.hardware_fixed], [["hard_drive~"], false])

	game.focus_job(job)
	game.go_to_view(&"Workview")
	game.lay_down(job)
	for i: int in Job.PANEL_SCREWS:
		game.turn_screw(job, i)
	game.open_case(job, true)
	check("the old drive comes out into the hand", [game.take_part(job, drive), game.hand.unwanted], [true, true])
	check("it can't go back in its box", game.return_part(drive), false)
	check("put back in: still not fixed", game.put_part(job, drive), true)
	game.open_case(job, false)
	for i: int in Job.PANEL_SCREWS:
		game.turn_screw(job, i)
	check("closed with the old drive: not fixed", job.hardware_fixed, false)

	for i: int in Job.PANEL_SCREWS:
		game.turn_screw(job, i)
	game.open_case(job, true)
	game.take_part(job, drive)
	check("the old drive goes in the trash", [game.trash_part(), Job.pieces_data(game.trashed).back()], [true, "hard_drive~"])
	check("a new drive from the storage goes in", [game.take_new_part(drive), game.put_part(job, drive), job.piece(drive).unwanted], [true, true, false])
	game.open_case(job, false)
	for i: int in Job.PANEL_SCREWS:
		game.turn_screw(job, i)
	check("closed with the new drive: fixed", [job.hardware_fixed, job.fixed, job.done], [true, true, false])
	game.stand_up(job)
	game.set_tested(job)
	check("tested: done", job.done, true)
	check("a restore keeps it done", game.restore(game.snapshot()), "")
	check("restored done, the new drive in", [game.jobs[0].done, Job.pieces_data([game.jobs[0].piece(drive)])], [true, ["hard_drive"]])

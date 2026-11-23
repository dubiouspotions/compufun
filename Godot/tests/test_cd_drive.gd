extends "res://tests/test.gd"
## The CD-ROM drive's tray: Game.toggle_cd_tray opens it on a running computer and closes it
## again, and keeps it in the snapshot; on a computer that is off, nothing moves. The drive shows the
## state: a change while the tray moves turns it around, and a new drive shows it at once.


func run() -> void:
	var tower: PcTower = load("res://props/pc_tower.tscn").instantiate()
	root.add_child(tower)
	var computer := Computer.new()
	computer.case_front = load("res://props/case_fronts/multimedia.tscn")
	tower.dress(computer)
	await process_frame
	var drive := tower.cd_drive()
	check("the multimedia front has a CD-ROM drive", drive != null, true)
	var tray: Node3D = drive.get_node(^"Tray")
	var closed := tray.position
	var moves := maxf(drive.open_delay + drive.open_seconds, drive.close_delay + drive.close_seconds) + 0.2

	var button: Node3D = drive.eject_button
	var out := button.position
	drive.dip(true)
	await create_timer(0.04).timeout
	check("the button dips in", button.position.z < out.z, true)
	await create_timer(moves).timeout
	check("and comes back out; the tray stays in", [button.position, drive.is_open, tray.position], [out, false, closed])

	drive.set_open(true)
	await create_timer(drive.open_delay * 0.5).timeout
	check("the latch clicks before the tray moves", tray.position, closed)
	await create_timer(moves).timeout
	check("open: the tray is out", [drive.is_open, tray.position.is_equal_approx(closed + Vector3(0, 0, drive.tray_travel))], [true, true])

	drive.set_open(false)
	await create_timer(moves).timeout
	check("closed: it is in again", [drive.is_open, tray.position.is_equal_approx(closed)], [false, true])
	drive.set_open(true)
	await create_timer(drive.open_delay + drive.open_seconds * 0.5).timeout
	var halfway := tray.position.z - closed.z
	drive.set_open(false)
	await create_timer(drive.reverse_pause * 0.5).timeout
	check("closing halfway out stops the tray", [drive.is_open, is_equal_approx(tray.position.z - closed.z, halfway), halfway > 0.0 and halfway < drive.tray_travel], [false, true, true])
	await create_timer(moves).timeout
	check("and takes it back in", tray.position.is_equal_approx(closed), true)
	drive.set_open(true, false)
	check("without animation, it is out at once", [drive.is_open, tray.position.is_equal_approx(closed + Vector3(0, 0, drive.tray_travel))], [true, true])
	drive.set_open(false, false)

	await _game_tray()

	var classic: Node = (load("res://props/case_fronts/classic.tscn") as PackedScene).instantiate()
	check("a classic front has none", classic.get_node_or_null(^"CdRom"), null)
	classic.free()
	tower.free()


# The tray as Game keeps it: only a running computer moves it, the snapshot keeps it, and the job's
# computer on the counter shows it.
func _game_tray() -> void:
	var entrepreneur: Customer = load("res://customers/young_entrepreneur.tres")
	game.start_day(make_day(1, [[entrepreneur, load("res://problems/email_virus.tres")]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	var computer: Node3D = load("res://rooms/shop/job_computer.tscn").instantiate()
	computer.set(&"job", job)
	root.add_child(computer)
	await process_frame
	var drive: CdDrive = computer.find_children("*", "CdDrive", true, false)[0]
	game.toggle_cd_tray(job)
	check("off, the tray stays in", [job.cd_tray_open, drive.is_open], [false, false])
	game.set_powered(job, true)
	game.toggle_cd_tray(job)
	check("on, it opens, and the computer's drive shows it", [job.cd_tray_open, drive.is_open], [true, true])
	game.set_powered(job, false)
	check("switching off leaves it out", job.cd_tray_open, true)
	check("a restore of the snapshot", game.restore(game.snapshot()), "")
	check("keeps it out", (game.jobs[0] as Job).cd_tray_open, true)
	computer.free()
	var rebuilt: Node3D = load("res://rooms/shop/job_computer.tscn").instantiate()
	rebuilt.set(&"job", game.jobs[0])
	root.add_child(rebuilt)
	await process_frame
	var shown: CdDrive = rebuilt.find_children("*", "CdDrive", true, false)[0]
	var tray: Node3D = shown.get_node(^"Tray")
	check("a new computer shows the open tray at once", [shown.is_open, is_equal_approx(tray.position.z - shown._tray_in.z, shown.tray_travel)], [true, true])
	game.set_powered(game.jobs[0], true)
	game.toggle_cd_tray(game.jobs[0])
	check("on again, it closes", [(game.jobs[0] as Job).cd_tray_open, shown.is_open], [false, false])
	rebuilt.free()

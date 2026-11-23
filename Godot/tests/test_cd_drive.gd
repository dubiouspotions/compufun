extends "res://tests/test.gd"
## The CD-ROM drive's tray: a press opens it on a running computer and closes it again, and a press
## while it moves turns it around; on a computer that is off, only the button clicks.


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

	drive.press(false)
	await create_timer(moves).timeout
	check("off, a press leaves the tray in", [drive.is_open, tray.position], [false, closed])

	drive.press(true)
	await create_timer(drive.open_delay * 0.5).timeout
	check("the latch clicks before the tray moves", tray.position, closed)
	await create_timer(moves).timeout
	check("on, a press opens the tray", [drive.is_open, tray.position.is_equal_approx(closed + Vector3(0, 0, drive.tray_travel))], [true, true])

	drive.press(true)
	await create_timer(moves).timeout
	check("and a second press closes it", [drive.is_open, tray.position.is_equal_approx(closed)], [false, true])
	drive.press(true)
	await create_timer(drive.open_delay + drive.open_seconds * 0.5).timeout
	var halfway := tray.position.z - closed.z
	drive.press(true)
	await create_timer(drive.reverse_pause * 0.5).timeout
	check("a press halfway out stops the tray", [drive.is_open, is_equal_approx(tray.position.z - closed.z, halfway), halfway > 0.0 and halfway < drive.tray_travel], [false, true, true])
	await create_timer(moves).timeout
	check("and takes it back in", tray.position.is_equal_approx(closed), true)

	var classic: Node = (load("res://props/case_fronts/classic.tscn") as PackedScene).instantiate()
	check("a classic front has none", classic.get_node_or_null(^"CdRom"), null)
	classic.free()
	tower.free()

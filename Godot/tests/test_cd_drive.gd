extends "res://tests/test.gd"
## The CD-ROM drive's tray: a press opens it on a running computer and closes it again; on a
## computer that is off, only the button clicks.


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
	var moves := drive.motor_delay + drive.slide_seconds + 0.2

	drive.press(false)
	await create_timer(moves).timeout
	check("off, a press leaves the tray in", [drive.is_open, tray.position], [false, closed])

	drive.press(true)
	await create_timer(drive.motor_delay * 0.5).timeout
	check("the motor spins up before the tray moves", tray.position, closed)
	await create_timer(moves).timeout
	check("on, a press opens the tray", [drive.is_open, tray.position.is_equal_approx(closed + Vector3(0, 0, drive.tray_travel))], [true, true])

	drive.press(true)
	await create_timer(moves).timeout
	check("and a second press closes it", [drive.is_open, tray.position.is_equal_approx(closed)], [false, true])
	var classic: Node = (load("res://props/case_fronts/classic.tscn") as PackedScene).instantiate()
	check("a classic front has none", classic.get_node_or_null(^"CdRom"), null)
	classic.free()
	tower.free()

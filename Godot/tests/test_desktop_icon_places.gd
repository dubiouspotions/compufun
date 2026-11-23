extends "res://tests/test.gd"
## A desktop icon stays where the player saw it: a change to the setup, moving one icon, or
## rebooting leaves the others where they stood after the boot.


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/skater_bro.tres"), load("res://problems/dust_overheat.tres"), 0, 0)
	game.jobs = [job] as Array[Job]
	var tall := Win95File.new()  # a three-line name makes the grid cells taller than My Computer
	tall.name = "A name long enough to wrap over three lines.txt"
	game.setup_for(job).desktop.append(tall)
	game.set_powered(job, true)
	await process_frame  # it boots offscreen, as a computer that the cable isn't on
	game.connect_cable(job)
	var desktop: Control = bench._desktops.get(job)
	var boot: Node = desktop.get("_boot")
	boot.set(&"_skipped", true)
	await boot.finished
	await create_timer(0.5).timeout
	var setup: Win95Setup = game.setup_for(job)
	var shown := _places(desktop, setup)
	check("the boot lines the icons up in columns", [shown["My Computer"], shown["Network Neighborhood"]], [Vector2(0, 0), Vector2(0, 75)])

	var state: Node = desktop.get_node("%ComputerState")
	state.set_sound(setup.volume, not setup.muted)
	await create_timer(0.5).timeout
	check("a change to the setup, such as Mute, moves no icon", _places(desktop, setup), shown)

	var moved: Win95File = setup.desktop.back()
	state.move_files([moved] as Array[Win95File], setup.desktop, [Vector2(300, 200)] as Array[Vector2])
	await create_timer(0.5).timeout
	var after := _places(desktop, setup)
	check("the moved icon stands where it was dropped", after[moved.name], Vector2(300, 200))
	after.erase(moved.name)
	shown.erase(moved.name)
	check("the others stay where they were", after, shown)

	game.set_powered(job, false)
	await create_timer(0.5).timeout
	game.set_powered(job, true)
	desktop = bench._desktops.get(job)
	boot = desktop.get("_boot")
	boot.set(&"_skipped", true)
	await boot.finished
	await create_timer(0.5).timeout
	after = _places(desktop, setup)
	after.erase(moved.name)
	check("and after a reboot", after, shown)
	game.jobs = [] as Array[Job]
	bench.free()


# Where each desktop file's icon stands, by file name.
func _places(desktop: Control, setup: Win95Setup) -> Dictionary:
	var places := {}
	for icon: Control in desktop.get_node("Desktop/DesktopIcons").get_children():
		var file: Win95File = icon.get_meta(&"win95_file", null)
		if file != null and setup.desktop.has(file):
			places[file.name] = icon.position
	return places

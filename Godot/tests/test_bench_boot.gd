extends "res://tests/test.gd"
## A computer that is switched on boots even while the cable is on another one, and connecting the
## cable later shows it as it got, without a new boot.


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/skater_bro.tres"), 0, 0)
	game.jobs = [job] as Array[Job]
	game.set_powered(job, true)
	await process_frame
	var desktop: Control = bench._desktops.get(job)
	check("switched on, not connected: a desktop runs", desktop != null and desktop.is_inside_tree(), true)
	check("off the screen", desktop.get_parent() != bench, true)
	var state: Node = desktop.get_node("%ComputerState")
	check("it booted", state.is_on, true)
	var boot: Node = desktop.get("_boot")
	check("the boot runs", is_instance_valid(boot) and boot.is_inside_tree(), true)
	game.connect_cable(job)
	await process_frame
	check("the cable shows the same desktop", [desktop.get_parent() == bench, bench._desktops.get(job) == desktop], [true, true])
	check("without a new boot", desktop.get("_boot") == boot, true)
	game.jobs = [] as Array[Job]
	bench.free()

extends "res://tests/test.gd"
## A computer that is switched on boots even while the cable is on another one, and connecting the
## cable later shows it as it got, without a new boot. The desktop then appears part by part. A
## restore that makes the job anew (a story reload) keeps it running.


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/skater_bro.tres"), load("res://problems/dust_overheat.tres"), 0, 0)
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

	boot.set(&"_skipped", true)
	while is_instance_valid(boot) and boot.self_modulate.a > 0.0:
		await process_frame
	var taskbar: Control = desktop.get_node("TaskBar")
	var icons: Array = desktop.get_node("Desktop/DesktopIcons").get_children()
	check("a skip lands on the bare desktop: the taskbar and pointer come last", [taskbar.modulate.a, desktop.get("pointer_visible")], [0.0, false])
	check("the clear boot still takes the input", [boot.visible, boot.mouse_filter, boot.has_focus()], [true, Control.MOUSE_FILTER_STOP, true])
	await boot.finished
	await process_frame
	check("then the whole desktop and the pointer show", [taskbar.modulate.a, icons.all(func(icon: Control) -> bool: return icon.modulate.a == 1.0), desktop.get("pointer_visible")], [1.0, true, true])

	var boots: int = state.get("_boots")
	var heir := Job.new(job.customer, job.problem, 0, 0)  # as Game.restore makes it, after a story reload
	heir.powered = true
	heir.broken = true
	game.jobs = [heir] as Array[Job]
	game.connected = heir
	game.changed.emit()
	await process_frame
	check("a restore's new job of the same computer runs on in the same desktop, with no boot", [bench._desktops.get(heir) == desktop, state.job == heir, state.is_on, state.get("_boots")], [true, true, true, boots])
	game.jobs = [] as Array[Job]
	bench.free()

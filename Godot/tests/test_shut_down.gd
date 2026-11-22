extends "res://tests/test.gd"
## Start > Shut Down leaves "It's now safe to turn off your computer" until the computer's power
## button turns it off: clicks and keys do nothing, a hang no longer comes, and the power stays on.
## Off and on again, Windows boots as usual, with the running copy as the player left it, and a
## fixed computer is tested once that boot reaches the desktop. Restart switches the power off and on
## by itself.

const SHUT_DOWN := "res://win95/shut_down.tscn"


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/skater_bro.tres"), load("res://problems/dust_overheat.tres"), 0, 0)
	game.jobs = [job] as Array[Job]
	game.set_powered(job, true)
	game.connect_cable(job)
	await process_frame
	var win95: Control = bench._desktops.get(job)
	var state: Node = win95.get_node("%ComputerState")
	var desktop: Node = win95.get_node("Desktop")
	state.call("set_sound", 33.0, false)
	(win95.get("_boot") as Node).finished.emit()
	check("the desktop is up", win95.get("pointer_visible"), true)

	var dialog: Node = desktop.call("open", load(SHUT_DOWN), false)
	dialog.get_node("%Yes").pressed.emit()
	await process_frame
	var cover := win95.get_child(win95.get_child_count() - 1) as Control
	check("the shut-down screen covers Windows", cover.get_node("Message").text, "It's now safe to turn off\nyour computer.")
	check("no pointer, the power stays on", [win95.get("pointer_visible"), state.get("is_on"), job.powered], [false, true, true])
	for event: InputEvent in [_click(), _key()]:
		cover._gui_input(event)
	await process_frame
	check("a click and a key leave it", is_instance_valid(cover) and cover.is_inside_tree(), true)
	await create_timer(job.problem.hangs_after + 0.3).timeout
	check("the overheating computer no longer hangs", [win95.process_mode, (win95.get("_buzz") as AudioStreamPlayer).playing], [Node.PROCESS_MODE_INHERIT, false])

	game.set_powered(job, false)
	await process_frame
	check("off: the shut-down screen goes, NO SIGNAL shows", [is_instance_valid(cover), (win95.get_node("%NoSignal") as Control).visible], [false, true])
	job.hardware_fixed = true
	game.set_powered(job, true)
	await process_frame
	var boot: Node = win95.get("_boot")
	check("on: Windows boots again", is_instance_valid(boot) and boot.is_inside_tree(), true)
	check("the running copy kept the player's change", state.get("setup").volume, 33.0)
	boot.finished.emit()
	await create_timer(job.problem.hangs_after + 0.3).timeout
	check("the fixed computer is tested at the desktop", job.tested, true)

	state.call("shut_down")
	game.set_powered(job, false)
	game.set_powered(job, true)
	check("a shut-down computer stays tested", job.tested, true)

	# Restart: the screen says so, then the power goes off and on again, and Windows boots.
	(win95.get("_boot") as Node).finished.emit()
	dialog = desktop.call("open", load(SHUT_DOWN), false)
	dialog.set(&"restart_wait_seconds", 0.2)
	dialog.set(&"restart_off_seconds", 0.4)
	(dialog.get_node("%Restart") as BaseButton).button_pressed = true
	dialog.get_node("%Yes").pressed.emit()
	await process_frame
	cover = win95.get_child(win95.get_child_count() - 1) as Control
	check("restart: the screen says it restarts, the power stays on", [cover.get_node("Message").text, job.powered], ["Please wait while your computer\nrestarts...", true])
	await create_timer(0.3).timeout
	check("then the power goes off: NO SIGNAL", [job.powered, is_instance_valid(cover), (win95.get_node("%NoSignal") as Control).visible], [false, false, true])
	await create_timer(0.5).timeout
	boot = win95.get("_boot")
	check("then on, and Windows boots", [job.powered, is_instance_valid(boot) and boot.is_inside_tree()], [true, true])
	check("the running copy still has the player's change", state.get("setup").volume, 33.0)
	game.jobs = [] as Array[Job]
	bench.free()


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _key() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	return event

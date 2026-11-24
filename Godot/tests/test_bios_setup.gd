extends "res://tests/test.gd"
## BIOS Setup: DEL during the POST opens it, a save keeps the choices in the computer's Win95Setup
## and resets the computer, and Boot Sequence C,A boots past a floppy in A: and fixes Bootfloppy.


func run() -> void:
	var boot: Control = load("res://win95/boot_sequence.tscn").instantiate()
	boot.play_on_start = false
	boot.floppy_in_a = true
	boot.warm_up_seconds = 0.1
	boot.line_seconds = 0.05
	boot.detect_seconds = 0.05
	boot.memory_test_seconds = 0.2
	boot.verify_seconds = 0.05
	boot.splash_seconds = 0.05
	boot.starting_seconds = 0.05
	boot.startup_sound = null
	boot.power_on_sound = null
	root.add_child(boot)
	var done := [false]
	boot.finished.connect(func() -> void: done[0] = true)
	boot.play()
	while not boot.get("_in_post"):
		await process_frame
	boot._gui_input(_key(KEY_DELETE))
	await process_frame
	check("DEL doesn't stop the POST", boot.get("_bios_setup"), null)
	while boot.get("_bios_setup") == null:
		await process_frame
	var setup: Control = boot.get("_bios_setup")
	check("BIOS Setup opens once the POST has finished", [setup.is_inside_tree(), "Secondary Slave" in boot.get_node("%Post").text], [true, true])

	for keycode: Key in [KEY_DOWN, KEY_ENTER, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_PAGEUP]:
		setup._gui_input(_key(keycode))
	check("Boot Sequence C,A, unsaved", [setup.get("_cmos"), boot.cmos_setup().cmos], [{&"boot_sequence": 1}, {}])
	setup._gui_input(_key(KEY_ESCAPE))
	setup._gui_input(_key(KEY_F10))
	setup._gui_input(_key(KEY_ENTER))
	check("saved to CMOS", boot.cmos_setup().cmos, {&"boot_sequence": 1})
	await process_frame
	check("setup closed, the POST runs again", [is_instance_valid(setup), boot.get("_bios_setup")], [false, null])

	for i in 600:
		if done[0]:
			break
		await process_frame
	check("C,A boots past the floppy in A:", done[0], true)

	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/skater_bro.tres"), load("res://problems/dust_overheat.tres"), 0, 0)
	game.jobs = [job] as Array[Job]
	game.set_powered(job, true)
	await process_frame
	var desktop: Control = bench._desktops.get(job)
	var state: Node = desktop.get_node("%ComputerState")
	var job_boot: Node = desktop.get("_boot")
	check("a customer's computer keeps its choices in its running copy", job_boot.get("computer") == state and job_boot.cmos_setup() == state.setup, true)
	game.set_powered(job, false)

	var floppy_job := Job.new(load("res://customers/young_entrepreneur.tres"), load("res://problems/bootfloppy.tres"), 1, 1)
	game.jobs = [floppy_job] as Array[Job]
	game.set_powered(floppy_job, true)
	await process_frame
	var floppy_state: Node = bench._desktops.get(floppy_job).get_node("%ComputerState")
	check("Bootfloppy: broken", floppy_job.software_fixed, false)
	floppy_state.apply_settings({&"cmos": {&"boot_sequence": 1} as Dictionary[StringName, int]} as Dictionary[StringName, Variant])
	check("saving Boot Sequence C,A fixes it, the floppy still in", [floppy_job.software_fixed, game.has_floppy(floppy_job)], [true, true])
	game.jobs = [] as Array[Job]
	bench.free()


func _key(keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key

extends "res://tests/test.gd"
## Disk Defragmenter on the skater's fragmented drive (errand 0403, day 4) runs until the first
## afternoon after it starts (Win95Setup.defrag_days, defrag_daypart), or the evening when no afternoon
## comes;
## paused, it stops. Switched off, it keeps its start: it finishes as the computer comes on after the
## finish, or else the next boot reopens its window, running; also after End Task on the window, a
## Shut Down and a restart, but not after Pause. Its window shows the share of the game's time from the
## start to the finish, and estimates the finish; a restore keeps the run. The case churns meanwhile.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload
const DEFRAG_PATH := "res://win95/defrag.tscn"
const GAME := preload("res://game.gd")


func run() -> void:
	var state := await _defragmenting()
	var job: Job = game.jobs[0]
	var setup: Win95Setup = state.get("setup")
	check("started on day 4 in the afternoon, it runs until the afternoon of day 5", [setup.defragmenting, setup.defrag_started_daypart, game.defrag_day(setup), setup.defrag_daypart, job.software_fixed],
			[true, GAME.Daypart.AFTERNOON, 5, &"afternoon", false])

	var window: Node = load(DEFRAG_PATH).instantiate()
	root.add_child(window)
	await process_frame
	window.set("_computer", state)
	window.call("_sync_computer")
	var estimate: Label = window.get_node("%Estimate")
	var progress: ProgressBar = window.get_node("%Progress")
	check("the window estimates it on day 4, at 0%", [estimate.visible, estimate.text, progress.value, window.get_node("%Start").text], [true, "Estimated time finished: Afternoon tomorrow", 0.0, "Pause"])
	await create_timer(2.0).timeout
	check("real seconds don't move it", progress.value, 0.0)

	game.close_shop()
	window.call("_sync_computer")
	check("the evening is a quarter of the way", progress.value, 25.0)
	game.start_next_day()
	window.call("_sync_computer")
	check("day 5 morning: still running, halfway", [game.day_number, setup.defragmenting, job.software_fixed, progress.value], [5, true, false, 50.0])
	check("and the estimate says today", estimate.text, "Estimated time finished: Afternoon today")
	game.daypart = GAME.Daypart.MIDDAY
	window.call("_sync_computer")
	check("midday: still running, at 75%", [setup.defragmenting, job.software_fixed, progress.value], [true, false, 75.0])

	var saved: Dictionary = game.snapshot()
	check("the snapshot holds when it started", saved["jobs"][0].get("defrag_started"), [4, "AFTERNOON"])
	game.reboot()
	check("a reboot forgets it", game.setups.is_empty(), true)
	check("restored", game.restore(JSON.parse_string(JSON.stringify(saved))), "")
	var restored: Win95Setup = game.setups.get(game.jobs[0].customer.computer)
	check("the restored run goes on, as far along", [restored.defragmenting, game.defrag_progress(restored)] if restored != null else [], [true, 0.75])
	check("a run on a computer that is off restores too", game.restore({"day": 5, "arrivals": 1, "jobs": [{"errand": "0403_skater_bro", "defrag_started": [4, "AFTERNOON"]}]}), "")
	restored = game.setups.get(game.jobs[0].customer.computer)
	check("with its start", [restored.defragmenting, restored.defrag_started_day], [true, 4])
	check("so is a daypart that isn't one", game.restore({"day": 5, "arrivals": 1, "jobs": [{"errand": "0403_skater_bro", "powered": true, "defrag_started": [4, "TEATIME"]}]}).contains("defrag_started"), true)
	window.queue_free()
	state.queue_free()
	await process_frame

	state = await _defragmenting()
	job = game.jobs[0]
	setup = state.get("setup")
	window = load(DEFRAG_PATH).instantiate()
	root.add_child(window)
	await process_frame
	window.set("_computer", state)
	window.call("_sync_computer")
	estimate = window.get_node("%Estimate")
	progress = window.get_node("%Progress")
	game.close_shop()
	game.start_next_day()
	game.daypart = GAME.Daypart.AFTERNOON
	window.call("_sync_computer")
	check("the afternoon finishes it and fixes the job", [setup.defragmenting, setup.fragmented, job.software_fixed, estimate.visible, progress.value], [false, false, true, false, 100.0])
	window.queue_free()
	state.queue_free()
	await process_frame

	state = await _defragmenting()
	setup = state.get("setup")
	game.close_shop()
	game.start_next_day()
	game.open_shop()
	game.daypart = GAME.Daypart.EVENING
	check("a day 5 with no afternoon finishes it in the evening", [setup.defragmenting, game.jobs[0].software_fixed], [false, true])
	state.queue_free()
	await process_frame

	state = await _defragmenting()
	setup = state.get("setup")
	window = load(DEFRAG_PATH).instantiate()
	root.add_child(window)
	await process_frame
	window.set("_computer", state)
	window.call("_sync_computer")
	game.close_shop()
	window.get_node("%Start").pressed.emit()
	check("Pause stops the run and puts it back at the start", [setup.defragmenting, window.get_node("%Progress").value, window.get_node("%Start").text], [false, 0.0, "Start"])
	game.start_next_day()
	window.get_node("%Start").pressed.emit()
	check("Start on day 5 in the morning runs it again until that afternoon", [setup.defragmenting, setup.defrag_started_day, game.defrag_day(setup), window.get_node("%Progress").value, window.get_node("%Estimate").text], [true, 5, 5, 0.0, "Estimated time finished: Afternoon today"])
	game.daypart = GAME.Daypart.MIDDAY
	window.get_node("%Start").pressed.emit()
	window.get_node("%Start").pressed.emit()
	check("paused and started again at midday, it still finishes that afternoon", [setup.defrag_started_daypart, game.defrag_day(setup)], [GAME.Daypart.MIDDAY, 5])
	game.daypart = GAME.Daypart.AFTERNOON
	check("and does", [setup.defragmenting, setup.fragmented], [false, false])
	setup.fragmented = true
	window.get_node("%Start").pressed.emit()
	check("started in the afternoon, it runs until the next afternoon", game.defrag_day(setup), 6)
	window.queue_free()
	state.queue_free()
	await process_frame

	state = await _defragmenting()
	setup = state.get("setup")
	game.set_powered(game.jobs[0], false)
	await process_frame
	check("switched off, it keeps its start", [setup.defragmenting, setup.defrag_started_day, setup.fragmented], [true, 4, true])
	game.close_shop()
	game.start_next_day()
	game.daypart = GAME.Daypart.AFTERNOON
	check("the finish passes while it is off: not finished yet", [setup.defragmenting, setup.fragmented, game.jobs[0].software_fixed], [true, true, false])
	game.set_powered(game.jobs[0], true)
	check("switched on after the finish, it finishes", [setup.defragmenting, setup.fragmented, game.jobs[0].software_fixed], [false, false, true])
	state.queue_free()
	await process_frame

	await _reopens()

	var computer: Node3D = load("res://rooms/shop/job_computer.tscn").instantiate()
	state = await _defragmenting()
	computer.set("job", game.jobs[0])
	root.add_child(computer)
	var drive: AudioStreamPlayer3D = computer.get_node("%HardDrive")
	for i in 60:
		await process_frame
	check("the case churns while it defragments, quietly, in the sound zones", [drive.stream in (load("res://sounds/defrag_seek.tres") as SoundSet).sounds, drive.volume_db <= -30.0, drive.area_mask & SoundSet.SOUND_ZONES != 0], [true, true, true])
	state.get("setup").defragmenting = false
	drive.stop()
	for i in 60:
		await process_frame
	check("and stops when the run ends", drive.playing, false)
	computer.queue_free()
	state.queue_free()
	await process_frame


# The bench screen's desktop of the skater's computer, booted, with Disk Defragmenter running in its
# window; each way that Windows goes down, and what the next boot opens.
func _reopens() -> void:
	game.reboot()
	check("restore the skater's computer, on and defragmenting", game.restore({"day": 4, "arrivals": 3, "phase": "OPEN", "connected_slot": 0, "jobs": [{"errand": "0403_skater_bro", "slot": 0, "powered": true, "defrag_started": [4, "AFTERNOON"]}]}), "")
	var job: Job = game.jobs[0]
	var setup: Win95Setup = game.setups[job.customer.computer]
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var win95: Control = bench._desktops.get(job)
	var desktop: Node = win95.get_node("Desktop")
	(win95.get("_boot") as Node).finished.emit()
	await process_frame
	var window := _defrag_window(desktop)
	check("a boot during a run opens Disk Defragmenter, running", [window != null, window.get_node("%Start").text if window != null else ""], [true, "Pause"])
	game.close_shop()

	game.set_powered(job, false)
	game.set_powered(job, true)
	check("switched off and on, it boots", [_defrag_window(desktop), is_instance_valid(win95.get("_boot"))], [null, true])
	(win95.get("_boot") as Node).finished.emit()
	await process_frame
	window = _defrag_window(desktop)
	check("and reopens it, as far along, with the same start", [window != null, window.get_node("%Progress").value if window != null else -1.0, setup.defrag_started_day], [true, 25.0, 4])

	win95.call(&"_on_action", &"close_program")
	var windows: Array = desktop.call(&"windows")
	var dialog: Node = windows[windows.size() - 1]
	var names: PackedStringArray = dialog.call(&"program_names")
	dialog.call(&"select", names.find("Disk Defragmenter"))
	dialog.get_node("%EndTask").pressed.emit()
	await process_frame
	check("End Task closes its window and keeps the run", [_defrag_window(desktop), setup.defragmenting], [null, true])
	win95.get_node("%ComputerState").call(&"shut_down")
	game.set_powered(job, false)
	game.set_powered(job, true)
	(win95.get("_boot") as Node).finished.emit()
	await process_frame
	check("after Shut Down and the power, the boot reopens it", _defrag_window(desktop) != null, true)

	win95.get_node("%ComputerState").call(&"restart", 0.05, 0.05)
	await create_timer(0.3).timeout
	check("a restart boots again", [job.powered, is_instance_valid(win95.get("_boot"))], [true, true])
	(win95.get("_boot") as Node).finished.emit()
	await process_frame
	window = _defrag_window(desktop)
	check("and reopens it", window != null, true)

	window.get_node("%Start").pressed.emit()
	check("Pause stops the run", setup.defragmenting, false)
	game.set_powered(job, false)
	game.set_powered(job, true)
	(win95.get("_boot") as Node).finished.emit()
	await process_frame
	check("so the next boot opens nothing", _defrag_window(desktop), null)
	game.jobs = [] as Array[Job]
	bench.free()


func _defrag_window(desktop: Node) -> Node:
	for window: Node in desktop.call(&"windows"):
		if window.scene_file_path == DEFRAG_PATH and window.visible and not window.is_queued_for_deletion():
			return window
	return null


# Day 4 after the skater's drop-off, his computer on, fragmented again, and Disk Defragmenter
# started on it.
func _defragmenting() -> Node:
	game.reboot()
	var refused: String = game.restore({"day": 4, "arrivals": 3, "phase": "OPEN", "jobs": [{"errand": "0403_skater_bro", "slot": 0, "powered": true}]})
	check("restore day 4 with the skater's computer on", refused, "")
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.set("job", game.jobs[0])
	root.add_child(state)
	await process_frame
	check("fragmented", [game.setups[game.jobs[0].customer.computer].fragmented, game.jobs[0].software_fixed], [true, false])
	state.call("start_defrag")
	return state

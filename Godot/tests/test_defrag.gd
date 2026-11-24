extends "res://tests/test.gd"
## Disk Defragmenter on the skater's fragmented drive (errand 0403, day 4) runs until the afternoon of
## the next day (Win95Setup.defrag_days, defrag_daypart), or the evening when no afternoon comes;
## switched off, it stops. Its window estimates when it finishes, and the case churns meanwhile.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload
const DEFRAG_PATH := "res://win95/defrag.tscn"
const GAME := preload("res://game.gd")


func run() -> void:
	var state := await _defragmenting()
	var job: Job = game.jobs[0]
	var setup: Win95Setup = state.get("setup")
	check("it runs until the afternoon of day 5", [setup.defragmenting, setup.defrag_day, setup.defrag_daypart, job.software_fixed], [true, 5, &"afternoon", false])

	var window: Node = load(DEFRAG_PATH).instantiate()
	root.add_child(window)
	await process_frame
	window.set("_computer", state)
	window.call("_sync_computer")
	var estimate: Label = window.get_node("%Estimate")
	check("the window estimates it on day 4", [estimate.visible, estimate.text], [true, "Estimated time finished: Afternoon tomorrow"])

	game.close_shop()
	game.start_next_day()
	window.call("_sync_computer")
	check("day 5 morning: still running", [game.day_number, setup.defragmenting, job.software_fixed], [5, true, false])
	check("and the estimate says today", estimate.text, "Estimated time finished: Afternoon today")
	game.daypart = GAME.Daypart.MIDDAY
	check("midday: still running", [setup.defragmenting, job.software_fixed], [true, false])
	game.daypart = GAME.Daypart.AFTERNOON
	window.call("_sync_computer")
	check("the afternoon finishes it and fixes the job", [setup.defragmenting, setup.fragmented, job.software_fixed, estimate.visible], [false, false, true, false])
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
	game.set_powered(game.jobs[0], false)
	await process_frame
	game.close_shop()
	game.start_next_day()
	game.daypart = GAME.Daypart.AFTERNOON
	check("switched off, it stops and stays fragmented", [setup.defragmenting, setup.fragmented, game.jobs[0].software_fixed], [false, true, false])
	state.queue_free()
	await process_frame

	var computer: Node3D = load("res://rooms/shop/job_computer.tscn").instantiate()
	state = await _defragmenting()
	computer.set("job", game.jobs[0])
	root.add_child(computer)
	var drive: AudioStreamPlayer3D = computer.get_node("%DefragDrive")
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

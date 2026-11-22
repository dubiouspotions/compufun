extends "res://tests/test.gd"
## The room's hums loop and follow what makes them: the storage bulb while it is lit, the work
## computer's fans while it runs, a computer's fans on the counter while it is on, and a monitor's
## hum while its tube is on.


func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var shop: Node = main.find_child("Shop", true, false)
	var bulb: Hum = shop.find_child("Storage", true, false).find_child("Light", false, false).get_node(^"Hum")
	var work_fan: Hum = shop.get_node(^"Room/WorkTower/Fan")
	var work_crt: Hum = shop.find_child("WorkMonitor", true, false).get_node(^"%Hum")
	var bench_crt: Hum = shop.find_child("Bench", true, false).get_node(^"Monitor/%Hum")
	for hum: Hum in [bulb, work_fan, work_crt, bench_crt]:
		check("%s loops" % hum.stream.resource_path, (hum.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)
		check("%s stays out of the Room reverb" % hum.stream.resource_path, hum.area_mask, 0)

	check("the storage bulb hums", bulb.playing, true)
	game.set_flag(&"storage_light_off")
	check("the bulb is off: silent", bulb.playing, false)
	game.set_flag(&"storage_light_off", 0)
	check("lit again: it hums", bulb.playing, true)

	check("the morning's work computer is off: silent", work_fan.playing, false)
	game.start_db()
	await _frames(2)
	check("the work computer runs: its fans hum", work_fan.playing, true)
	check("both monitors are on: they hum", [work_crt.playing, bench_crt.playing], [true, true])

	main.get_node(^"%ScreenView").toggle_power()
	await create_timer(1.0).timeout
	check("the bench monitor switched off: silent", bench_crt.playing, false)

	check("restore a computer on the counter, switched on", game.restore({"jobs": [
		{"customer": "res://customers/skater_bro.tres", "problem": "dust_overheat", "slot": 0, "powered": true}]}), "")
	await _frames(2)
	var fan: Hum = shop.find_child("JobSlots", true, false).find_children("Fan", "Hum", true, false)[0]
	check("its fans hum", fan.playing, true)
	game.set_powered(game.jobs[0], false)
	check("switched off: silent", fan.playing, false)
	main.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

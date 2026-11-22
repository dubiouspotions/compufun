extends "res://tests/test.gd"
## The rain loops play only while it rains, and the open loop sounds as open as the door: muffled and
## low while the door is shut, bright and loud while a customer holds it open.


func run() -> void:
	var outside: Node = load("res://rooms/shop/outside.tscn").instantiate()
	root.add_child(outside)
	var shop := Node3D.new()
	root.add_child(shop)
	var door: Node3D = (load("res://props/door.tscn") as PackedScene).instantiate()
	shop.add_child(door)
	var walker := Node3D.new()
	walker.add_to_group(&"customer_bodies")
	walker.position = Vector3(5, 0, 5)
	shop.add_child(walker)
	var rain_open: AudioStreamPlayer = outside.get_node("%RainOpen")
	var rain_shut: AudioStreamPlayer = outside.get_node("%RainShut")
	var street := AudioServer.get_bus_index(&"Street")
	var filter := AudioServer.get_bus_effect(street, 0) as AudioEffectLowPassFilter
	await process_frame

	check("restore day 1, open", game.restore({"day": 1, "phase": "OPEN"}), "")
	check("dry: no rain sound", [rain_open.playing, rain_shut.playing], [false, false])
	check("restore day 2, open", game.restore({"day": 2, "phase": "OPEN"}), "")
	check("rain: both loops play", [rain_open.playing, rain_shut.playing], [true, true])
	check("the open loop on the Street bus, the muffled one on Master", [rain_open.bus, rain_shut.bus], [&"Street", &"Master"])
	check("both loop", [(rain_open.stream as AudioStreamWAV).loop_mode, (rain_shut.stream as AudioStreamWAV).loop_mode], [AudioStreamWAV.LOOP_FORWARD, AudioStreamWAV.LOOP_FORWARD])

	await create_timer(0.3).timeout
	check("door shut: the street is muffled and low", [roundi(filter.cutoff_hz), roundi(AudioServer.get_bus_volume_db(street))], [500, -20])
	walker.position = Vector3(0.58, 0, -0.6)
	await create_timer(0.15).timeout
	var cutoff_swinging := filter.cutoff_hz
	await create_timer(0.6).timeout
	check("the muffle opens with the swing", [cutoff_swinging > 500.0, cutoff_swinging < filter.cutoff_hz], [true, true])
	check("door open: bright and loud", [filter.cutoff_hz > 5000.0, AudioServer.get_bus_volume_db(street) > -3.0], [true, true])
	walker.position = Vector3(5, 0, 5)
	await create_timer(3.0).timeout
	check("door shut again: muffled", [filter.cutoff_hz < 700.0, AudioServer.get_bus_volume_db(street) < -15.0], [true, true])

	check("restore day 2, closed for the night", game.restore({"day": 2, "phase": "DAY_OVER", "daypart": "EVENING"}), "")
	game.start_next_day()
	check("the next day is dry: the rain stops", [rain_open.playing, rain_shut.playing], [false, false])
	outside.queue_free()
	shop.queue_free()
	await process_frame

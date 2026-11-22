extends "res://tests/test.gd"
## No change sound plays when the state jumps (Game.jump): not when the game starts, not on a
## restore and not when a new day starts. The street ambience, the rain and the hums are loops, not changes.

const LOOPS: Array[String] = ["res://sounds/city_ambience.ogg", "res://sounds/rain_open.wav", "res://sounds/rain_shut.wav",
	"res://sounds/light_hum.wav", "res://sounds/pc_fan.wav", "res://sounds/crt_hum.wav"]

var _players := {}  # every audio player, and whether it played on the last frame
var _started: Array[String] = []


func run() -> void:
	node_added.connect(_track)
	process_frame.connect(_poll)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	check("the game starts with the street ambience and hums only", _changes(), [])
	check("the street ambience plays", "res://sounds/city_ambience.ogg" in _started, true)

	_hush()
	check("restore day 1 at night, CompuFunDB on, a computer plugged in", game.restore({"day": 1, "phase": "DAY_OVER", "db_day": 1,
		"jobs": [{"customer": "res://customers/skater_bro.tres", "problem": "dust_overheat", "slot": 0}], "connected_slot": 0}), "")
	await _frames(10)
	check("a restore plays no change sound", _changes(), [])

	_hush()
	game.start_next_day()
	await _frames(40)  # past the second relay click of a lost signal
	check("day 2 starts", game.day_number, 2)
	check("a new day plays no change sound", _changes(), [])

	_hush()
	game.connect_cable(null)
	await _frames(2)
	check("pulling the cable out still sounds", _changes(), ["res://sounds/cable_plug_out.ogg"])
	main.queue_free()
	await process_frame


func _track(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		_players[node] = false


func _poll() -> void:
	for player: Variant in _players.keys():
		if not is_instance_valid(player):
			_players.erase(player)
			continue
		var playing: bool = player.get(&"playing")
		var stream: AudioStream = player.get(&"stream")
		if playing and not _players[player]:
			_started.append(stream.resource_path if stream != null else "null")
		_players[player] = playing


# Stops every change sound and forgets what started: headless, a sound never ends, so its replay would go unseen.
func _hush() -> void:
	for player: Variant in _players.keys():
		if is_instance_valid(player) and player.get(&"stream") != null and player.get(&"stream").resource_path not in LOOPS:
			player.call(&"stop")
			_players[player] = false
	_started.clear()


func _changes() -> Array[String]:
	return _started.filter(func(path: String) -> bool: return path not in LOOPS)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

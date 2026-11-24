extends "res://tests/test.gd"
## The corruption sign pointer_escape: day 3 starts it and day 7's close ends it. While it shows, the Win95
## arrow now and then stays the cursor for a while after the mouse leaves the bench screen of a
## Cambion computer. The rolls repeat after the same restore.

const SKATER: String = "res://customers/skater_bro.tres"


func run() -> void:
	check("day 3 starts the sign, and day 7's close takes it back",
			[game.day_of(3).set_flags.get(&"sign_pointer_escape"), game.day_of(7).close_flags.get(&"sign_pointer_escape")], [1, 0])

	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var sign: Node = main.find_child("PointerEscape", true, false)
	var screen: Control = main.get_node(^"%ScreenView").call(&"crt_screen")  # untyped: ScreenView names Game
	check("the sign is in the shop", sign != null, true)

	check("a Cambion computer on the bench", _restore({&"sign_pointer_escape": 1, &"skater_bro_runs_cambion": 1}), "")
	await _frames(2)
	sign.set(&"escape_chance", 1.0)
	screen.mouse_exited.emit()
	check("the mouse left the screen: the arrow lingers", sign.call(&"is_lingering"), true)
	await create_timer(float(sign.get(&"linger_seconds")) + 0.2).timeout
	check("a while later the game's cursor is back", sign.call(&"is_lingering"), false)
	screen.mouse_exited.emit()
	screen.mouse_entered.emit()
	check("back on the screen: it ends at once", sign.call(&"is_lingering"), false)
	sign.set(&"escape_chance", 0.0)
	screen.mouse_exited.emit()
	check("chance 0: it never lingers", sign.call(&"is_lingering"), false)
	sign.set(&"escape_chance", 1.0)
	screen.mouse_exited.emit()
	game.set_flag(&"skater_bro_runs_cambion", 0)
	check("Cambion uninstalled mid-linger: the game's cursor is back", sign.call(&"is_lingering"), false)

	sign.set(&"escape_chance", 1.0)
	check("a computer without Cambion", _restore({&"sign_pointer_escape": 1}), "")
	await _frames(2)
	screen.mouse_exited.emit()
	check("its arrow doesn't come along", sign.call(&"is_lingering"), false)
	check("Cambion, but the sign off", _restore({&"skater_bro_runs_cambion": 1}), "")
	await _frames(2)
	screen.mouse_exited.emit()
	check("the arrow doesn't come along", sign.call(&"is_lingering"), false)
	check("the sign on", _restore({&"sign_pointer_escape": 1, &"skater_bro_runs_cambion": 1}), "")
	screen.mouse_exited.emit()
	game.set_flag(&"sign_pointer_escape", 0)
	check("the sign taken back mid-linger: the game's cursor is back", sign.call(&"is_lingering"), false)

	sign.set(&"escape_chance", 0.2)
	var first := await _rolls(sign, screen)
	var second := await _rolls(sign, screen)
	check("the same restore rolls the same", second, first)
	check("some of 40 exits linger, most don't", [first.count(true) > 0, first.count(true) < 20], [true, true])
	main.queue_free()
	await _frames(2)


func _restore(flags: Dictionary) -> String:
	return game.restore({"day": 4, "view": "Screen", "connected_slot": 0, "flags": flags,
			"jobs": [{"customer": SKATER, "problem": "dust_overheat", "slot": 0, "powered": true}]})


# Whether each of 40 exits after a fresh restore lingers.
func _rolls(sign: Node, screen: Control) -> Array[bool]:
	_restore({&"sign_pointer_escape": 1, &"skater_bro_runs_cambion": 1})
	await _frames(2)
	var rolls: Array[bool] = []
	for i in 40:
		screen.mouse_exited.emit()
		rolls.append(sign.call(&"is_lingering"))
		screen.mouse_entered.emit()
	return rolls


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

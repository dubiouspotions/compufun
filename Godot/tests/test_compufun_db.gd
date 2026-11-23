extends "res://tests/test.gd"
## CompuFunDB's search: Enter lists the symptoms that hold the typed words, one at a time; picking
## one offers the checks of every problem with it among checks of other problems in the same place;
## only one problem's checks marked show its fix. The search, with its marks and ticks, survives a
## snapshot and a restore, and a malformed one
## is refused.

## CompuFunDB.Column, which a test can't name: CompuFunDB names the Game autoload.
const SEARCH: int = 0
const CHECKS: int = 1
const FIXES: int = 2


func run() -> void:
	_check_game()
	await _check_screen()


func _check_game() -> void:
	check("a fresh day", game.restore({"day": 1}), "")
	check("no search yet", game.db_search, null)
	var search: DbSearch = game.search_db("Sound is muted", ["Volume is on", "Colour scheme is the usual"])
	check("nothing marked", [search.query, search.marked_checks], ["Sound is muted", []])
	game.mark_check("Volume is on", true)
	game.mark_check("Volume is on", true)
	check("a check is marked once", search.marked_checks, ["Volume is on"])
	game.tick_repair("Unmute", true)
	game.tick_repair("Unmute", false)
	check("a repair unticks", search.ticked_repairs, [])
	game.tick_repair("Unmute", true)

	game.start_db()
	check("restore the snapshot", game.restore(game.snapshot()), "")
	check("the start-up day survives", game.db_day, 1)
	var restored: DbSearch = game.db_search
	check("the search survives", [restored.query, restored.offered], ["Sound is muted", ["Volume is on", "Colour scheme is the usual"]])
	check("the marks and ticks survive", [restored.marked_checks, restored.ticked_repairs], [["Volume is on"], ["Unmute"]])

	var refused: String = game.restore({"db_search": {"query": "x", "marked_checks": "oops"}})
	check("a list that is not a list is refused", refused.contains("marked_checks of the CompuFunDB search 'x' is not a list"), true)
	check("the refusal keeps the search", game.db_search, restored)
	check("the old records are ignored", game.restore({"records": [{"text": "x"}]}), "")
	check("a restore without a search starts empty", [game.db_search, game.db_day], [null, 0])


# The two problems with "Computer overheating" get checks of their own, so the test doesn't hang on the files' wording.
func _check_screen() -> void:
	var dust: Problem = load("res://problems/dust_overheat.tres")
	var hamster: Problem = load("res://problems/hamster.tres")
	dust.checks = ["Windows stays up", "CPU fan is clean"]
	hamster.checks = ["Windows stays up", "Nothing blocks the CPU fan"]
	check("a fresh day, CompuFunDB on", game.restore({"day": 1, "db_day": 1}), "")
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	db.set("hdd_seek", null)
	db.set("search_seconds", Vector2(0.2, 0.2))
	db.set("hit_seconds", Vector2(0.2, 0.2))
	root.add_child(db)
	await process_frame
	check("nothing listed before typing", _texts(db, SEARCH), [])
	check("right goes nowhere without a search", [_press(db, KEY_RIGHT), db.get("_column")], [true, SEARCH])
	for letter: String in "OVERheat":
		_type(db, letter)
	check("typing finds nothing yet", _texts(db, SEARCH), [])
	_press(db, KEY_ENTER)
	check("Enter searches, slowly", [db.get("_searching"), _texts(db, SEARCH)], [true, []])
	await create_timer(0.5).timeout  # the read, then the first hit
	check("the first symptom found shows alone", _texts(db, SEARCH), ["Computer overheating"])
	await create_timer(0.25).timeout
	check("then the next, whatever the case", [_texts(db, SEARCH), db.get("_searching")], [["Computer overheating", "GPU overheating"], false])
	db.set("search_seconds", Vector2.ZERO)
	db.set("hit_seconds", Vector2.ZERO)
	_press(db, KEY_BACKSPACE)
	check("backspace erases", db.get("_typed"), "OVERhea")
	_press(db, KEY_P)
	check("P types in SEARCH", db.get("_typed"), "OVERheap")
	for i: int in 8:
		_press(db, KEY_BACKSPACE)
	for letter: String in "computer over":
		_type(db, letter)
	check("typing clears what was found", _texts(db, SEARCH), [])
	_press(db, KEY_ENTER)
	check("every word must be in it", _texts(db, SEARCH), ["Computer overheating"])
	_press(db, KEY_ENTER)
	var search: DbSearch = game.db_search
	check("Enter picks it, the cursor in CHECK", [search.query, db.get("_column")], ["Computer overheating", CHECKS])
	var right: Array[String] = ["Windows stays up", "CPU fan is clean", "Nothing blocks the CPU fan"]
	var others: Array = search.offered.filter(func(c: String) -> bool: return c not in right)
	check("the checks of both problems are offered", right.all(func(c: String) -> bool: return c in search.offered), true)
	var hardware := _hardware_checks()
	check("with 2 to 5 checks of other hardware problems", [others.size() >= 2 and others.size() <= 5, others.all(func(c: String) -> bool: return c in hardware)], [true, true])
	check("no fix before a mark", _texts(db, FIXES), [])

	game.mark_check("Windows stays up", true)
	game.mark_check("CPU fan is clean", true)
	check("the dust problem's checks show its fix alone", _texts(db, FIXES).count("Test the computer"), 1)
	game.mark_check(others[0], true)
	check("a wrong mark hides it", _texts(db, FIXES), [])
	game.mark_check(others[0], false)

	db.set("hit_seconds", Vector2(0.2, 0.2))
	game.mark_check("CPU fan is clean", false)
	game.mark_check("CPU fan is clean", true)
	check("a fix that shows again is read in, not there at once", _texts(db, FIXES), [])
	await create_timer(0.3).timeout
	check("one entry at a time", _texts(db, FIXES).size(), 1)
	db.set("hit_seconds", Vector2.ZERO)
	game.mark_check("CPU fan is clean", false)
	game.mark_check("CPU fan is clean", true)

	var printer: Node3D = load("res://props/printer.tscn").instantiate()
	printer.add_to_group(&"printer")
	root.add_child(printer)
	check("F prints outside SEARCH", _press(db, KEY_F), true)
	var page: PackedStringArray = printer.get("_lines")
	check("a FIX page for the search", [page[0].begins_with("CompuFunDB 1.0  FIX  "), page[2], "FIX" in page], [true, "SEARCH: Computer", true])
	printer.queue_free()
	check("Esc leaves", _press(db, KEY_ESCAPE), false)
	db.queue_free()


# The checks of every problem with a hardware part, but those of the two problems searched for.
func _hardware_checks() -> Array[String]:
	var checks: Array[String] = []
	for file: String in ResourceLoader.list_directory("res://problems/"):
		var problem := load("res://problems/" + file) as Problem if file.ends_with(".tres") else null
		if problem != null and problem.location != Problem.Location.SOFTWARE and problem.short_name not in [&"dust_overheat", &"hamster"]:
			checks.append_array(problem.checks)
	return checks


func _texts(db: Control, column: int) -> Array:
	return db.call("_entries", column).map(func(entry: Dictionary) -> String: return entry.text)


func _press(db: Control, key: Key) -> bool:
	var event := InputEventKey.new()
	event.keycode = key
	event.unicode = OS.get_keycode_string(key).to_lower().unicode_at(0) if key >= KEY_A and key <= KEY_Z else 0
	event.pressed = true
	return db.call("_on_key", event)


func _type(db: Control, letter: String) -> void:
	var event := InputEventKey.new()
	event.unicode = letter.unicode_at(0)
	event.pressed = true
	db.call("_on_key", event)

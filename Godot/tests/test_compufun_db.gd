extends "res://tests/test.gd"
## CompuFunDB's search: typed words list the symptoms that hold them; picking one offers what goes
## with it among 2 to 5 symptoms of other problems in the same place; only the right marks show the
## fix. The search, with its marks and ticks, survives a snapshot and a restore, and a malformed one
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
	var search: DbSearch = game.search_db("Sound is muted", ["Window colours changed drastically", "Sound is muted"])
	check("the query is marked", [search.query, search.marked_symptoms], ["Sound is muted", ["Sound is muted"]])
	game.mark_symptom("Window colours changed drastically", true)
	game.mark_symptom("Window colours changed drastically", true)
	check("a symptom is marked once", search.marked_symptoms, ["Sound is muted", "Window colours changed drastically"])
	game.tick_repair("Unmute", true)
	game.tick_repair("Unmute", false)
	check("a repair unticks", search.ticked_repairs, [])
	game.tick_repair("Unmute", true)

	game.start_db()
	check("restore the snapshot", game.restore(game.snapshot()), "")
	check("the start-up day survives", game.db_day, 1)
	var restored: DbSearch = game.db_search
	check("the search survives", [restored.query, restored.offered], ["Sound is muted", ["Window colours changed drastically", "Sound is muted"]])
	check("the marks and ticks survive", [restored.marked_symptoms, restored.ticked_repairs], [["Sound is muted", "Window colours changed drastically"], ["Unmute"]])

	var refused: String = game.restore({"db_search": {"query": "x", "marked_symptoms": "oops"}})
	check("a list that is not a list is refused", refused.contains("marked_symptoms of the CompuFunDB search 'x' is not a list"), true)
	check("the refusal keeps the search", game.db_search, restored)
	check("the old records are ignored", game.restore({"records": [{"text": "x"}]}), "")
	check("a restore without a search starts empty", [game.db_search, game.db_day], [null, 0])


func _check_screen() -> void:
	check("a fresh day, CompuFunDB on", game.restore({"day": 1, "db_day": 1}), "")
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	root.add_child(db)
	await process_frame
	check("nothing listed before typing", _texts(db, SEARCH), [])
	check("right goes nowhere without a search", [_press(db, KEY_RIGHT), db.get("_column")], [true, SEARCH])
	for letter: String in "OVERheat":
		_type(db, letter)
	check("the words find symptoms, whatever the case", _texts(db, SEARCH), ["Computer overheating", "GPU overheating"])
	_press(db, KEY_BACKSPACE)
	check("backspace erases", db.get("_typed"), "OVERhea")
	_press(db, KEY_P)
	check("P types in SEARCH", db.get("_typed"), "OVERheap")
	for key: Key in [KEY_BACKSPACE, KEY_BACKSPACE, KEY_BACKSPACE, KEY_BACKSPACE, KEY_BACKSPACE, KEY_BACKSPACE, KEY_BACKSPACE, KEY_BACKSPACE]:
		_press(db, key)
	for letter: String in "computer over":
		_type(db, letter)
	check("every word must be in it", _texts(db, SEARCH), ["Computer overheating"])
	_press(db, KEY_ENTER)
	var search: DbSearch = game.db_search
	check("Enter picks it, the cursor in CHECK", [search.query, db.get("_column")], ["Computer overheating", CHECKS])
	var right: Array[String] = ["Hangs and reboots at startup", "Computer overheating"]  # dust_overheat and hamster
	var decoys: Array = search.offered.filter(func(s: String) -> bool: return s not in right)
	check("every right symptom is offered", right.all(func(s: String) -> bool: return s in search.offered), true)
	check("with 2 to 5 others", decoys.size() >= 2 and decoys.size() <= 5, true)
	var hardware := _hardware_symptoms()
	check("the others are of a hardware problem", decoys.all(func(s: String) -> bool: return s in hardware), true)
	check("no fix with one mark", _texts(db, FIXES), [])

	game.mark_symptom("Hangs and reboots at startup", true)
	check("the right marks show the fixes of both problems", _texts(db, FIXES).count("Test the computer"), 2)
	game.mark_symptom(decoys[0], true)
	check("a wrong mark hides them", _texts(db, FIXES), [])
	game.mark_symptom(decoys[0], false)

	var printer: Node3D = load("res://props/printer.tscn").instantiate()
	printer.add_to_group(&"printer")
	root.add_child(printer)
	check("F prints outside SEARCH", _press(db, KEY_F), true)
	var page: PackedStringArray = printer.get("_lines")
	check("a FIX page for the search", [page[0].begins_with("CompuFunDB 1.0  FIX  "), page[2], "FIX" in page], [true, "SEARCH: Computer", true])
	printer.queue_free()
	check("Esc leaves", _press(db, KEY_ESCAPE), false)
	db.queue_free()


func _hardware_symptoms() -> Array[String]:
	var symptoms: Array[String] = []
	for file: String in ResourceLoader.list_directory("res://problems/"):
		var problem := load("res://problems/" + file) as Problem if file.ends_with(".tres") else null
		if problem != null and problem.location != Problem.Location.SOFTWARE:
			symptoms.append_array(problem.symptoms)
	return symptoms


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

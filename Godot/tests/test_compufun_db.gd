extends "res://tests/test.gd"
## CompuFunDB's search: Enter lists the symptoms that hold the typed words, one at a time; picking
## one offers the checks of every cause of it, and lists those causes; a check ticked as passing rules out the causes that need it to fail, and F
## prints the selected cause's fix. The search, with its ticks, survives a snapshot and a restore,
## and a malformed one is refused.

## CompuFunDB.Column, which a test can't name: CompuFunDB names the Game autoload.
const SEARCH: int = 0
const CHECKS: int = 1
const CAUSES: int = 2


func run() -> void:
	_check_game()
	await _check_screen()


func _check_game() -> void:
	check("a fresh day", game.restore({"day": 1}), "")
	check("no search yet", game.db_search, null)
	var search: DbSearch = game.search_db("Sound is muted", ["Volume is on", "Colour scheme is the usual"])
	check("nothing ticked", [search.query, search.ticked_checks], ["Sound is muted", []])
	game.mark_check("Volume is on", true)
	game.mark_check("Volume is on", true)
	check("a check is ticked once", search.ticked_checks, ["Volume is on"])
	game.mark_check("Colour scheme is the usual", true)
	game.mark_check("Colour scheme is the usual", false)
	check("and unticks", search.ticked_checks, ["Volume is on"])

	game.start_db()
	check("restore the snapshot", game.restore(game.snapshot()), "")
	check("the start-up day survives", game.db_day, 1)
	var restored: DbSearch = game.db_search
	check("the search survives", [restored.query, restored.offered], ["Sound is muted", ["Volume is on", "Colour scheme is the usual"]])
	check("the ticks survive", restored.ticked_checks, ["Volume is on"])

	var refused: String = game.restore({"db_search": {"query": "x", "ticked_checks": "oops"}})
	check("a list that is not a list is refused", refused.contains("ticked_checks of the CompuFunDB search 'x' is not a list"), true)
	check("the refusal keeps the search", game.db_search, restored)
	check("the old records are ignored", game.restore({"records": [{"text": "x"}]}), "")
	check("a restore without a search starts empty", [game.db_search, game.db_day], [null, 0])


# On the problem files as they are: "Restarts by itself" is a symptom of four causes; the dust and the
# hamster share their checks, so ticks leave both possible, and the player prints the one they see.
func _check_screen() -> void:
	const FREEZES := "Freezes with a buzz after the desktop appears"
	const FAN := "CPU fan is clean and spins freely"
	check("a fresh day, CompuFunDB on", game.restore({"day": 1, "db_day": 1}), "")
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	db.set("hdd_seek", null)
	db.set("search_seconds", Vector2(0.2, 0.2))
	db.set("hit_seconds", Vector2(0.2, 0.2))
	root.add_child(db)
	await process_frame
	check("nothing listed before typing", _texts(db, SEARCH), [])
	check("right goes nowhere without a search", [_press(db, KEY_RIGHT), db.get("_column")], [true, SEARCH])
	for letter: String in "PICture":
		_type(db, letter)
	check("typing finds nothing yet", _texts(db, SEARCH), [])
	_press(db, KEY_ENTER)
	check("Enter searches, slowly", [db.get("_searching"), _texts(db, SEARCH)], [true, []])
	await create_timer(0.5).timeout  # the read, then the first hit
	check("the first symptom found shows alone", _texts(db, SEARCH).size(), 1)
	await create_timer(0.4).timeout
	check("then the rest, whatever the case", [_texts(db, SEARCH), db.get("_searching")], [["Garbled picture", "No picture at all", "Can't open pictures"], false])
	db.set("search_seconds", Vector2.ZERO)
	db.set("hit_seconds", Vector2.ZERO)
	_press(db, KEY_BACKSPACE)
	check("backspace erases", db.get("_typed"), "PICtur")
	_press(db, KEY_P)
	check("P types in SEARCH", db.get("_typed"), "PICturp")
	for i: int in 7:
		_press(db, KEY_BACKSPACE)
	for letter: String in "restarts by":
		_type(db, letter)
	check("typing clears what was found", _texts(db, SEARCH), [])
	_press(db, KEY_ENTER)
	check("every word must be in it, and a shared symptom shows once", _texts(db, SEARCH), ["Restarts by itself"])
	_press(db, KEY_ENTER)
	var search: DbSearch = game.db_search
	check("Enter picks it, the cursor in CHECK", [search.query, db.get("_column")], ["Restarts by itself", CHECKS])
	game.mark_check(search.offered[0], true)
	_press(db, KEY_LEFT)
	_press(db, KEY_ENTER)
	check("picking it again keeps the search and its ticks", [game.db_search, search.ticked_checks, db.get("_column")], [search, [search.offered[0]], CHECKS])
	game.mark_check(search.offered[0], false)
	var right: Array[String] = ["Memory test fails at startup", "Windows starts", "Bluescreen after the desktop appears", "Windows stays up after the desktop appears", FREEZES, "Dust in the CPU fan", FAN, "Something lies on the CPU fan"]
	check("CHECK lists the checks of its causes, and no others, in their order", search.offered, right)
	check("its four causes, by name", _texts(db, CAUSES), ["Bad RAM module", "Failing hard drive", "Clogged CPU fan", "Blocked CPU fan"])
	check("all possible before a tick", _possible(db), [true, true, true, true])

	game.mark_check(FREEZES, true)
	check("a yes: ticked rules out the causes that don't say yes: to it", _possible(db), [false, false, true, true])
	game.mark_check("Dust in the CPU fan", true)
	check("so does the next", _possible(db), [false, false, true, false])
	game.mark_check("Dust in the CPU fan", false)
	game.mark_check(FAN, true)
	check("a no: ticked rules out the causes that say no: to it", _possible(db), [false, false, false, false])
	game.mark_check(FAN, false)
	game.mark_check(FREEZES, false)
	game.mark_check("Windows starts", true)
	check("a no: of one cause leaves the others", _possible(db), [false, true, true, true])
	game.mark_check("Windows starts", false)

	db.set("hit_seconds", Vector2(0.2, 0.2))
	_press(db, KEY_ENTER)  # ticks the check under the cursor, which doesn't change what CAUSES shows
	_press(db, KEY_ENTER)
	check("ticks don't read the causes in again", _texts(db, CAUSES).size(), 4)
	db.call("_search", "Restarts by itself")
	check("a new search reads them in again, not there at once", [_texts(db, CHECKS), _texts(db, CAUSES)], [[], []])
	await create_timer(0.3).timeout
	check("one entry at a time, CHECK first", [_texts(db, CHECKS).size(), _texts(db, CAUSES).size()], [1, 0])
	check("only CHECK's header spins meanwhile", [db.call("_busy", CHECKS), db.call("_busy", CAUSES)], [true, false])
	db.set("hit_seconds", Vector2.ZERO)
	db.call("_search", "Restarts by itself")
	game.mark_check(FREEZES, true)

	_press(db, KEY_LEFT)
	_type(db, " ")
	check("typing hides CHECK and CAUSES until a symptom is picked again", [_texts(db, CHECKS), _texts(db, CAUSES)], [[], []])
	_press(db, KEY_BACKSPACE)
	_press(db, KEY_ENTER)
	_press(db, KEY_ENTER)
	check("picked again, they show", _texts(db, CAUSES).size(), 4)
	game.mark_check(FREEZES, true)

	var printer: Node3D = load("res://props/printer.tscn").instantiate()
	printer.add_to_group(&"printer")
	root.add_child(printer)
	_press(db, KEY_RIGHT)
	check("the cursor skips the ruled-out causes", db.call("_selected_cause").cause_name(), "Clogged CPU fan")
	_press(db, KEY_DOWN)
	check("F prints outside SEARCH", _press(db, KEY_F), true)
	var page: PackedStringArray = printer.get("_lines")
	check("a FIX page for the cause", [page[0].begins_with("CompuFunDB 1.0  FIX  "), page[2], page[5]], [true, "SEARCH: Restarts by itself", "Blocked CPU fan"])
	check("with its steps and the test", [Array(page).any(func(l: String) -> bool: return l.begins_with("2. Clear the CPU fan")), page[-1].begins_with("4. Test the computer")], [true, true])
	game.mark_check(FAN, true)
	_press(db, KEY_F)
	check("a ruled-out cause prints nothing", printer.get("_lines"), page)
	printer.queue_free()
	check("Esc leaves", _press(db, KEY_ESCAPE), false)
	db.queue_free()



func _possible(db: Control) -> Array:
	return db.call("_entries", CAUSES).map(func(entry: Dictionary) -> bool: return entry.pick)


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

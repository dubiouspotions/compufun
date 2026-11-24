extends "res://tests/test.gd"
## CompuFunDB: a symptom picked lists its causes' checks and the causes; a ticked no: rules a cause
## out; F prints the picked cause's fix. The search survives a snapshot and a restore. With
## filter_search, the default, SEARCH lists every symptom and narrows the list as the player types;
## off, it searches on Enter. A click outside SEARCH's field stops the letters typing into it, until
## a click on the field.

## CompuFunDB.Column, which a test can't name: CompuFunDB names the Game autoload.
const CAUSES: int = 1
const CHECKS: int = 2


func run() -> void:
	check("a fresh day, CompuFunDB on", game.restore({"day": 1, "db_day": 1}), "")
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	db.set("hdd_seek", null)
	db.set("search_seconds", Vector2.ZERO)
	db.set("hit_seconds", Vector2.ZERO)
	root.add_child(db)
	await process_frame
	check("the search filters by default", db.get("filter_search"), true)
	db.set("filter_search", false)
	check("a keyword finds its symptom", db.call("_found", "audio"), PackedStringArray(["No sound"]))
	for letter: String in "restarts":
		var key := InputEventKey.new()
		key.unicode = letter.unicode_at(0)
		key.pressed = true
		db.call("_on_key", key)
	_press(db, KEY_ENTER)
	_press(db, KEY_ENTER)
	check("unfiltered, Enter searches, Enter picks", [game.db_search.query, db.get("_column")], ["Restarts by itself", CHECKS])
	check("its causes; the dust and the hamster are one", _texts(db, CAUSES), ["Faulty graphics card", "Bad RAM module", "Failing hard drive", "Faulty CPU fan"])

	game.mark_check("Windows starts", true)
	check("a ticked no: rules out its causes", _possible(db), [true, false, true, true])
	game.mark_check("Freezes with a buzz after the desktop appears", true)
	check("and no others", _possible(db), [false, false, false, true])

	check("restore the snapshot", game.restore(game.snapshot()), "")
	check("the search survives", [game.db_search.query, game.db_search.ticked_checks.size()], ["Restarts by itself", 2])

	var printer: Node3D = load("res://props/printer.tscn").instantiate()
	printer.add_to_group(&"printer")
	root.add_child(printer)
	_press(db, KEY_LEFT)
	_press(db, KEY_F)
	var page: PackedStringArray = printer.get("_lines")
	check("F prints the picked cause's fix", [page[5], "\n".join(page).contains("4. Connect it, switch")], ["Faulty CPU fan", true])
	printer.queue_free()

	_press(db, KEY_ESCAPE)  # the print box's OK
	db.set("_column", 0)  # SEARCH
	db.call("_type", "")
	db.set("filter_search", true)
	var every: Array = _texts(db, 0)
	check("filtering, an empty SEARCH lists every symptom", [every.size(), every.size() > 3], [(db.get("_symptoms") as PackedStringArray).size(), true])
	for letter: String in "audio":
		var key := InputEventKey.new()
		key.unicode = letter.unicode_at(0)
		key.pressed = true
		db.call("_on_key", key)
	check("typing narrows the list at once", [_texts(db, 0), db.get("_searching")], [["No sound"], false])
	_press(db, KEY_ENTER)
	check("Enter picks", [game.db_search.query, db.get("_column")], ["No sound", CHECKS])

	db.set("_column", 0)
	db.call("_type", "")
	_click(db, Vector2i(10, 20))  # below the list
	_letter(db, "p")
	check("after a click outside the field, letters don't type", [db.get("_typed"), _texts(db, 0).size()], ["", (db.get("_symptoms") as PackedStringArray).size()])
	_click(db, Vector2i(10, 2))  # the field
	_letter(db, "p")
	check("a click on the field takes the letters again", db.get("_typed"), "p")
	db.queue_free()


func _possible(db: Control) -> Array:
	return db.call("_entries", CAUSES).map(func(entry: Dictionary) -> bool: return entry.pick)


func _texts(db: Control, column: int) -> Array:
	return db.call("_entries", column).map(func(entry: Dictionary) -> String: return entry.text)


func _letter(db: Control, letter: String) -> void:
	var key := InputEventKey.new()
	key.unicode = letter.unicode_at(0)
	key.pressed = true
	db.call("_on_key", key)


func _click(db: Control, cell: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(8, 16)
	db.call("_on_click", event)


func _press(db: Control, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	db.call("_on_key", event)

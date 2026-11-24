extends "res://tests/test.gd"
## CompuFunDB: a symptom picked lists its causes' checks and the causes; a ticked no: rules a cause
## out; F prints the picked cause's fix. The search survives a snapshot and a restore.

## CompuFunDB.Column, which a test can't name: CompuFunDB names the Game autoload.
const CHECKS: int = 1
const CAUSES: int = 2


func run() -> void:
	check("a fresh day, CompuFunDB on", game.restore({"day": 1, "db_day": 1}), "")
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	db.set("hdd_seek", null)
	db.set("search_seconds", Vector2.ZERO)
	db.set("hit_seconds", Vector2.ZERO)
	root.add_child(db)
	await process_frame
	check("a keyword finds its symptom", db.call("_found", "audio"), PackedStringArray(["No sound"]))
	for letter: String in "restarts":
		var key := InputEventKey.new()
		key.unicode = letter.unicode_at(0)
		key.pressed = true
		db.call("_on_key", key)
	_press(db, KEY_ENTER)
	_press(db, KEY_ENTER)
	check("Enter searches, Enter picks", [game.db_search.query, db.get("_column")], ["Restarts by itself", CHECKS])
	check("its causes; the dust and the hamster are one", _texts(db, CAUSES), ["Bad RAM module", "Failing hard drive", "Faulty CPU fan"])

	game.mark_check("Windows starts", true)
	check("a ticked no: rules out its causes", _possible(db), [false, true, true])
	game.mark_check("Freezes with a buzz after the desktop appears", true)
	check("and no others", _possible(db), [false, false, true])

	check("restore the snapshot", game.restore(game.snapshot()), "")
	check("the search survives", [game.db_search.query, game.db_search.ticked_checks.size()], ["Restarts by itself", 2])

	var printer: Node3D = load("res://props/printer.tscn").instantiate()
	printer.add_to_group(&"printer")
	root.add_child(printer)
	_press(db, KEY_RIGHT)
	_press(db, KEY_F)
	var page: PackedStringArray = printer.get("_lines")
	check("F prints the picked cause's fix", [page[5], page[-1].begins_with("5. Test the computer")], ["Faulty CPU fan", true])
	printer.queue_free()
	db.queue_free()


func _possible(db: Control) -> Array:
	return db.call("_entries", CAUSES).map(func(entry: Dictionary) -> bool: return entry.pick)


func _texts(db: Control, column: int) -> Array:
	return db.call("_entries", column).map(func(entry: Dictionary) -> String: return entry.text)


func _press(db: Control, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	db.call("_on_key", event)

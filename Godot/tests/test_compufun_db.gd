extends "res://tests/test.gd"
## A computer on the counter gets one CompuFunDB record; the record, with its marked symptoms and
## ticked repairs, survives a snapshot and a restore, and a malformed record is refused. The list
## shows only the records of the computers on the counter, and the cursor follows its record.

const CUSTOMER: String = "res://customers/skater_bro.tres"
## CompuFunDB.Column, which a test can't name: CompuFunDB names the Game autoload.
const RECORDS: int = 0
const CHECKS: int = 1
const OTHERS: Array[String] = ["res://customers/retired_accountant.tres", "res://customers/activist_guy.tres"]


func run() -> void:
	check("a job on the counter", game.restore({"day": 1, "arrivals": 1, "jobs": [{"customer": CUSTOMER, "order": 7}]}), "")
	var job: Job = game.jobs[0]
	check("no record yet", game.record_of(job), null)
	var record: DbRecord = game.enter_job(job, "Skater bro: turns off")
	check("the record is the job's", game.record_of(job), record)
	check("the record keeps the job's order", record.job_order, 7)
	game.mark_symptom(record, "Fan clogged with dust", true)
	game.mark_symptom(record, "Fan clogged with dust", true)
	check("a symptom is marked once", record.marked_symptoms, ["Fan clogged with dust"])
	game.tick_repair(record, "Install the fan", true)
	game.tick_repair(record, "Install the fan", false)
	check("a repair unticks", record.ticked_repairs, [])
	game.tick_repair(record, "Install the fan", true)

	check("CompuFunDB hasn't started up today", game.db_day, 0)
	game.start_db()
	check("start-up is remembered for the day", game.db_day, 1)
	check("restore the snapshot", game.restore(game.snapshot()), "")
	check("the start-up day survives", game.db_day, 1)
	var restored: DbRecord = game.records[0]
	check("the text survives", restored.text, "Skater bro: turns off")
	check("the marks survive", restored.marked_symptoms, ["Fan clogged with dust"])
	check("the ticks survive", restored.ticked_repairs, ["Install the fan"])
	check("the job still has its record", game.record_of(game.jobs[0]), restored)

	var refused: String = game.restore({"records": [{"text": "x", "marked_symptoms": "oops"}]})
	check("a list that is not a list is refused", refused.contains("marked_symptoms of the record 'x' is not a list"), true)
	check("the refusal keeps the records", game.records[0], restored)
	check("a restore without records starts empty", game.restore({}), "")
	check("no records", game.records.size(), 0)
	check("and no start-up", game.db_day, 0)
	await _check_picked_up()


# A computer that leaves the counter takes its record off the list; Game keeps the record.
func _check_picked_up() -> void:
	var jobs: Array = []
	for i: int in 3:
		jobs.append({"customer": ([CUSTOMER] + OTHERS)[i], "order": i})
	check("three jobs", game.restore({"day": 1, "arrivals": 3, "jobs": jobs}), "")
	for i: int in 3:
		game.enter_job(game.jobs[i], "record %d" % i)
	game.start_db()
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	root.add_child(db)
	await process_frame
	check("all three listed", _texts(db), ["record 0", "record 1", "record 2"])
	for key: Key in [KEY_DOWN, KEY_DOWN, KEY_RIGHT]:
		_press(db, key)
	check("on the last record's checks", [db.call("_record").text, db.get("_column")], ["record 2", CHECKS])
	_check_categories(db)

	_leave(0)
	check("the first record left the list", _texts(db), ["record 1", "record 2"])
	check("Game keeps it", game.records.size(), 3)
	check("the cursor stays on its record and column", [db.call("_record").text, db.get("_column")], ["record 2", CHECKS])

	_leave(2)
	check("the selected record left", _texts(db), ["record 1"])
	check("the cursor goes back to the list, on the record left", [db.call("_record").text, db.get("_column")], ["record 1", RECORDS])
	db.queue_free()


# The CHECK column lists the symptoms under their categories' headings, in check_categories' order,
# and the cursor and the mouse pass over the headings.
func _check_categories(db: Control) -> void:
	var entries: Array = db.call("_entries", CHECKS)
	var headings: Array = entries.filter(func(entry: Dictionary) -> bool: return not entry.pick).map(func(entry: Dictionary) -> String: return entry.text)
	check("a heading per category, in order", headings, Array(db.get("check_categories")).map(func(category: String) -> String: return "-- %s --" % category))
	check("a heading comes first", entries[0].pick, false)
	check("the cursor settles on the first symptom, under it", db.get("_selected")[CHECKS], 1)
	var startup: int = entries.find(entries.filter(func(entry: Dictionary) -> bool: return entry.text == "-- At startup --")[0])
	db.get("_selected")[CHECKS] = startup - 1
	_press(db, KEY_DOWN)
	check("Down steps over a heading", db.get("_selected")[CHECKS], startup + 1)
	_press(db, KEY_UP)
	check("and Up back over it", db.get("_selected")[CHECKS], startup - 1)
	var record: DbRecord = db.call("_record")
	var lines: Array = db.call("_lines", CHECKS, entries)
	var row: int = lines.map(func(line: Array) -> int: return line[0]).find(startup) - db.get("_scroll")[CHECKS]
	check("the heading is on screen", row >= 0 and row <= db.LIST_BOTTOM - db.LIST_TOP, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (Vector2(db.get("_spans")[CHECKS].x, db.LIST_TOP + row) + Vector2(0.5, 0.5)) * db.CELL
	db.call("_on_click", click)
	check("a click on a heading marks nothing and leaves the cursor", [record.marked_symptoms.is_empty(), db.get("_selected")[CHECKS]], [true, startup - 1])


# The computer of job [param order] leaves the counter; its record stays in Game.
func _leave(order: int) -> void:
	var state: Dictionary = game.snapshot()
	state.jobs = state.jobs.filter(func(job: Dictionary) -> bool: return job.order != order)
	check("job %d leaves" % order, game.restore(state), "")


func _texts(db: Control) -> Array:
	return db.call("_entries", RECORDS).map(func(entry: Dictionary) -> String: return entry.text)


func _press(db: Control, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	db.call("_on_key", event)

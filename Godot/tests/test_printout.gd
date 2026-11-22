extends "res://tests/test.gd"
## The printout that the player carries: taken from the printer, ticked, held up beside a screen,
## thrown away, kept through a snapshot and the day, and gone the next day.

const PAGE: PackedStringArray = ["CompuFunDB 1.0  CHECKLIST  05/31/96", "", "CHECK", "[X] Fan clogged with dust", "FIX", "1. Install the fan      [ ]"]
const FIX_PAGE: PackedStringArray = ["CompuFunDB 1.0  FIX  05/31/96", "", "FIX", "1. Install the fan      [ ]"]


func run() -> void:
	game.start_day(load("res://days/day_1.tres"))
	check("nothing carried at the start", game.printout, PackedStringArray())
	check("nothing to throw", game.trash_printout(), false)
	check("nothing to tick", game.tick_printout(3, true), false)

	check("carry a page", [game.carry_printout(PAGE), game.printout], [true, PAGE])
	check("the hand stays free", game.hand, null)
	check("tick a symptom", [game.tick_printout(3, true), game.printout_ticks], [true, [3]])
	check("tick a step", [game.tick_printout(5, true), game.printout_ticks], [true, [3, 5]])
	check("a line without a box takes no tick", [game.tick_printout(2, true), game.printout_ticks], [false, [3, 5]])
	check("untick", [game.tick_printout(3, false), game.printout_ticks], [true, [5]])
	var record_marks: Array = game.records.map(func(r: DbRecord) -> Array: return r.ticked_repairs)
	check("ticks change no record", record_marks, [])

	var saved: Dictionary = game.snapshot()
	game.trash_printout()
	check("restore", game.restore(saved), "")
	check("the page and its ticks come back", [game.printout, game.printout_ticks], [PAGE, [5]])
	var refused: String = game.restore({"printout": {"lines": Array(PAGE), "ticks": [2]}})
	check("a tick on a line without a box is refused", refused.contains("line 2 has no check box"), true)
	check("the refusal keeps the page", game.printout_ticks, [5])

	var refusals: Array[int] = [0]
	game.printout_refused.connect(func() -> void: refusals[0] += 1)
	check("a second page is refused, the first one kept", [game.carry_printout(FIX_PAGE), game.printout, game.printout_ticks, refusals[0]], [false, PAGE, [5], 1])
	check("throw it away", [game.trash_printout(), game.printout], [true, PackedStringArray()])
	check("then the next page goes, unticked", [game.carry_printout(FIX_PAGE), game.printout, game.printout_ticks], [true, FIX_PAGE, []])
	game.trash_printout()
	check("the snapshot carries none", game.snapshot()["printout"], {})

	game.carry_printout(PAGE)
	game.start_next_day()
	check("gone the next day", [game.day_number, game.printout], [2, PackedStringArray()])
	check("a restore without a printout carries none", [game.restore({}), game.printout], ["", PackedStringArray()])
	await _check_printer()
	await _check_close_up()
	await _check_trash_can()
	await _check_print_fix()


# The finished page at the printer goes to the player and leaves the printer.
func _check_printer() -> void:
	var printer: Node3D = load("res://props/printer.tscn").instantiate()  # untyped: Printer names Game
	root.add_child(printer)
	await process_frame
	check("no page to take yet", printer.call("take_page"), false)
	printer.call("print_page", PAGE)
	check("no taking while it prints", printer.call("take_page"), false)
	await create_timer(PAGE.size() * float(printer.get("line_seconds")) + float(printer.get("feed_seconds")) + 0.3).timeout
	check("take the printed page", [printer.call("take_page"), game.printout], [true, PAGE])
	check("the page left the printer", printer.call("take_page"), false)
	printer.call("print_page", FIX_PAGE)
	await create_timer(FIX_PAGE.size() * float(printer.get("line_seconds")) + float(printer.get("feed_seconds")) + 0.3).timeout
	check("carrying a page, the next one stays in the printer", [printer.call("take_page"), game.printout], [false, PAGE])
	game.trash_printout()
	check("with the hands free, it comes", [printer.call("take_page"), game.printout], [true, FIX_PAGE])
	game.trash_printout()
	printer.queue_free()


# The corner shows while the player carries a page; the close-up ticks a box under a click.
func _check_close_up() -> void:
	game.carry_printout(PAGE)
	var carried: Control = load("res://ui/carried_printout.tscn").instantiate()  # untyped: CarriedPrintout names Game
	root.add_child(carried)
	await process_frame
	var corner: Control = carried.get_node("%Corner")
	check("the corner shows the carried page", corner.visible, true)
	carried.call("open")
	check("the close-up opens, the corner hides", [carried.call("is_open"), corner.visible], [true, false])
	var paper: Control = carried.get_node("%Paper")
	var box: Rect2 = paper.call("box_rect", 5)
	check("the step's box is on its line", paper.call("line_at", box.get_center()), 5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = box.get_center()
	paper.gui_input.emit(click)
	check("a click on the box ticks it", game.printout_ticks, [5])
	paper.gui_input.emit(click)
	check("a second click unticks it", game.printout_ticks, [])

	carried.call("hold_beside", Rect2(400, 60, 1280, 960))
	var held: Control = carried.get_node("%Held")
	check("held up beside a screen, the close-up and the corner go", [carried.call("is_held"), carried.call("is_open"), corner.visible], [true, false, false])
	await create_timer(float(carried.get("hold_seconds")) + 0.1).timeout
	check("the held page stays left of the screen", held.get_global_rect().end.x <= 400.0, true)
	check("the held page's text is in the window", held.position.x + held.call("cell").x * int(held.get("margin_chars")) >= 0.0, true)
	click.position = held.call("box_rect", 5).get_center()
	held.gui_input.emit(click)
	check("a click on the held page's box ticks it", game.printout_ticks, [5])
	carried.call("hold_beside", Rect2())
	check("away from the screen, back in the corner", [carried.call("is_held"), corner.visible], [false, true])
	carried.call("hold_beside", Rect2(400, 60, 1280, 960))
	game.trash_printout()
	check("thrown away, nothing is held", carried.call("is_held"), false)
	check("thrown away, the close-up and the corner go", [carried.call("is_open"), corner.visible], [false, false])
	carried.queue_free()


# The trash can is outlined while the player carries a page, and a click throws the page away; a part
# in the hand goes first.
func _check_trash_can() -> void:
	var can: Node3D = load("res://props/trash_can.tscn").instantiate()  # untyped: TrashCan names Game
	root.add_child(can)
	await process_frame
	var outline: Node3D = can.get_node("%Outline")
	var hotspot: Node = can.get_node("%Hotspot")
	check("no page, no part: no outline", outline.visible, false)
	game.carry_printout(PAGE)
	check("carrying a page outlines the can", outline.visible, true)
	game.take_new_part(load("res://parts/fan.tres"))
	hotspot.clicked.emit(hotspot)
	check("a part in the hand goes first", [game.hand, game.trashed.size(), game.printout], [null, 1, PAGE])
	hotspot.clicked.emit(hotspot)
	check("then a click throws the page away", [game.printout, game.view != &"Trash", outline.visible], [PackedStringArray(), true, false])
	can.queue_free()


# CompuFunDB's F prints the FIX steps alone; with no FIX steps it prints nothing.
func _check_print_fix() -> void:
	var printer: Node3D = load("res://props/printer.tscn").instantiate()
	printer.add_to_group(&"printer")
	root.add_child(printer)
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	root.add_child(db)
	game.restore({"day": 1, "phase": "OPEN", "arrivals": 1, "jobs": [{"customer": "res://customers/skater_bro.tres", "problem": "dust_overheat", "slot": 0}]})
	game.db_day = game.day_number
	var record: DbRecord = game.enter_job(game.jobs[0], "Skater bro: Windows starts and turns off")
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	check("no FIX steps, nothing to print", [db.call("_on_key", key), printer.get("_lines")], [true, PackedStringArray()])
	game.mark_symptom(record, "Hangs and reboots at startup", true)
	game.mark_symptom(record, "Fan clogged with dust", true)
	db.call("_on_key", key)
	var page: PackedStringArray = printer.get("_lines")
	check("F prints a FIX page", [page[0].begins_with("CompuFunDB 1.0  FIX  "), "FIX" in page, "CHECK" in page], [true, true, false])
	check("with the steps and their boxes", page[-1].ends_with("[ ]"), true)
	db.queue_free()
	printer.queue_free()

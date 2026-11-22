extends "res://tests/test.gd"
## The printout that the player carries: taken from the printer, ticked, raised, held up beside a screen,
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
	var taken := _count_plays(printer)
	check("take the printed page, with a rustle", [printer.call("take_page"), game.printout, taken[0]], [true, PAGE, 1])
	check("the page left the printer", printer.call("take_page"), false)
	printer.call("print_page", FIX_PAGE)
	await create_timer(FIX_PAGE.size() * float(printer.get("line_seconds")) + float(printer.get("feed_seconds")) + 0.3).timeout
	check("carrying a page, the next one stays in the printer, silent", [printer.call("take_page"), game.printout, taken[0]], [false, PAGE, 1])
	game.trash_printout()
	check("with the hands free, it comes", [printer.call("take_page"), game.printout], [true, FIX_PAGE])
	game.trash_printout()
	printer.queue_free()


# The corner shows at the bottom left while the player carries a page; a click raises the page on the
# right, where a click on a box ticks it and a click elsewhere on it or outside it lowers it. A click
# outside reaches nothing else. Beside an open screen the page is always up.
func _check_close_up() -> void:
	game.carry_printout(PAGE)
	var behind := Control.new()  # a stand-in for the buttons and hotspots under the page
	var behind_clicks: Array[int] = [0]
	behind.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			behind_clicks[0] += 1)
	root.add_child(behind)
	behind.size = behind.get_viewport_rect().size
	var carried: Control = load("res://ui/carried_printout.tscn").instantiate()  # untyped: CarriedPrintout names Game
	var handled := _count_plays(carried)
	root.add_child(carried)
	await process_frame
	var view: Vector2 = carried.get_viewport_rect().size
	var corner: Control = carried.get_node("%Corner")
	check("the corner shows the carried page", corner.visible, true)
	check("the corner is at the bottom left", [corner.get_global_rect().end.x < view.x * 0.5, corner.get_global_rect().end.y >= view.y], [true, true])
	var arrow := Rect2(view.x - 108.0, view.y * 0.5 - 66.0, 84.0, 132.0)
	var buttons: Array[Rect2] = [arrow]
	var none: Array[Rect2] = []
	carried.call("lay_out_around", Rect2(), buttons)
	carried.call("raise")
	var paper: Control = carried.get_node("%Paper")
	check("raised, the page is up and the corner hides, with a rustle", [carried.call("is_raised"), corner.visible, handled[0]], [true, false, 1])
	await create_timer(float(carried.get("raise_seconds")) + 0.1).timeout
	var page: Rect2 = paper.get_global_rect()
	check("the raised page is on the right, left of the arrow", [page.position.x >= view.x * 0.5, page.end.x <= arrow.position.x], [true, true])
	var box: Rect2 = paper.call("box_rect", 5)
	check("the step's box is on its line", paper.call("line_at", box.get_center()), 5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = box.get_center()
	paper.gui_input.emit(click)
	check("a click on the box ticks it", game.printout_ticks, [5])
	paper.gui_input.emit(click)
	check("a second click unticks it; ticks don't rustle", [game.printout_ticks, handled[0]], [[], 1])
	click.position = paper.call("box_rect", 3).get_center() - Vector2(0.0, paper.call("cell").y)
	paper.gui_input.emit(click)
	check("a click on a line without a box lowers it, with a rustle", [carried.call("is_raised"), corner.visible, game.printout_ticks, handled[0]], [false, true, [], 2])

	carried.call("raise")
	await create_timer(float(carried.get("raise_seconds")) + 0.1).timeout
	page = paper.get_global_rect()
	_click_at(page.position + paper.call("box_rect", 5).get_center())
	check("a real click on the box ticks it and keeps it up", [game.printout_ticks, carried.call("is_raised"), behind_clicks[0]], [[5], true, 0])
	_click_at(Vector2(page.position.x - 40.0, page.get_center().y))
	check("a click outside lowers it, with a rustle, and reaches nothing else", [carried.call("is_raised"), corner.visible, behind_clicks[0], handled[0]], [false, true, 0, 4])
	_click_at(Vector2(page.position.x - 40.0, page.get_center().y))
	check("lowered, a click there reaches what is under it", behind_clicks[0], 1)
	game.tick_printout(5, false)

	var screen := Rect2(320, 60, 1280, 960)
	carried.call("lay_out_around", screen, none)
	check("beside an open screen the page is up", [carried.call("is_raised"), corner.visible], [true, false])
	await create_timer(float(carried.get("raise_seconds")) + 0.1).timeout
	page = paper.get_global_rect()
	check("the page stays right of the screen", page.position.x >= screen.end.x, true)
	check("its text is in the window", page.end.x - paper.call("cell").x * int(paper.get("margin_chars")) <= view.x, true)
	click.position = paper.call("box_rect", 5).get_center()
	paper.gui_input.emit(click)
	check("a click on its box ticks it", game.printout_ticks, [5])
	_click_at(screen.get_center())
	check("a click on the screen keeps it up and reaches the screen", [carried.call("is_raised"), behind_clicks[0]], [true, 2])
	carried.call("lower")
	check("beside the screen it stays up", carried.call("is_raised"), true)
	carried.call("lay_out_around", Rect2(), none)
	check("away from the screen, back in the corner", [carried.call("is_raised"), corner.visible], [false, true])
	carried.call("raise")
	game.trash_printout()
	check("thrown away, the page and the corner go", [carried.call("is_raised"), corner.visible], [false, false])
	carried.call("raise")
	check("nothing carried, nothing to raise", carried.call("is_raised"), false)
	carried.queue_free()
	behind.queue_free()


# The sounds that start under [param node] from now on: SoundSet.play_at adds a player for each.
func _count_plays(node: Node) -> Array[int]:
	var plays: Array[int] = [0]
	node.child_entered_tree.connect(func(child: Node) -> void:
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			plays[0] += 1)
	return plays


# A left press and release at [param at], in the window's coordinates, through the whole input chain.
func _click_at(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		root.push_input(click, true)


# The trash can is outlined while the player carries a page, and a click throws the page away; a part
# in the hand goes first.
func _check_trash_can() -> void:
	var can: Node3D = load("res://props/trash_can.tscn").instantiate()  # untyped: TrashCan names Game
	var thrown := _count_plays(can)
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
	check("then a click throws the page away, with a rustle", [game.printout, game.view != &"Trash", outline.visible, thrown[0]], [PackedStringArray(), true, false, 1])
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

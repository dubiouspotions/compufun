extends "res://tests/test.gd"
## The printout that the player carries: taken from the printer, ticked, raised, held up beside a screen,
## thrown away, kept through a snapshot and the day, and gone the next day.

const PAGE: PackedStringArray = ["CompuFunDB 1.0  CHECKLIST  05/31/96", "", "CHECK", "[X] Fan clogged with dust", "FIX", "1. Install the fan      [ ]"]
const FIX_PAGE: PackedStringArray = ["CompuFunDB 1.0  FIX  05/31/96", "", "FIX", "1. Install the fan      [ ]"]


func run() -> void:
	game.start_day(game.day_of(1))
	check("nothing carried at the start", game.printout, PackedStringArray())
	check("nothing to throw", game.trash_printout(), false)
	check("nothing to tick", game.tick_printout(3, true), false)

	check("carry a page", [game.carry_printout(PAGE), game.printout], [true, PAGE])
	check("the hand stays free", game.hand, null)
	check("tick a symptom", [game.tick_printout(3, true), game.printout_ticks], [true, [3]])
	check("tick a step", [game.tick_printout(5, true), game.printout_ticks], [true, [3, 5]])
	check("a line without a box takes no tick", [game.tick_printout(2, true), game.printout_ticks], [false, [3, 5]])
	check("untick", [game.tick_printout(3, false), game.printout_ticks], [true, [5]])
	check("ticks change no search", game.db_search, null)

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
	await _check_trash_raised()


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
# right, where a click on a box ticks it, a click elsewhere on it keeps it up, a click outside reaches
# what is under it, and a click on its folded corner lowers it. While a customer talks it is down. Beside an open
# screen the page is always up.
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
	var corner_paper: Control = carried.get_node("%CornerPaper")
	var page_right: Vector2 = corner_paper.get_global_transform() * Vector2(corner_paper.size.x, 0.0)
	check("the corner shows the page's whole width", corner.get_global_rect().end.x >= page_right.x, true)
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
	var pencil: SoundSet = carried.get("tick_sound")
	var eraser: SoundSet = carried.get("untick_sound")
	paper.gui_input.emit(click)
	check("a click on the box ticks it, in pencil", [game.printout_ticks, handled[0], _latest_sound(carried) in pencil.sounds], [[5], 2, true])
	paper.gui_input.emit(click)
	check("a second click rubs it out", [game.printout_ticks, handled[0], _latest_sound(carried) in eraser.sounds], [[], 3, true])
	click.position = paper.call("box_rect", 3).get_center() - Vector2(0.0, paper.call("cell").y)
	paper.gui_input.emit(click)
	check("a click on a line without a box keeps it up", [carried.call("is_raised"), corner.visible, game.printout_ticks, handled[0]], [true, false, [], 3])

	carried.call("raise")
	await create_timer(float(carried.get("raise_seconds")) + 0.1).timeout
	page = paper.get_global_rect()
	_click_at(page.position + paper.call("box_rect", 5).get_center())
	check("a real click on the box ticks it and keeps it up", [game.printout_ticks, carried.call("is_raised"), behind_clicks[0]], [[5], true, 0])
	_click_at(Vector2(page.position.x - 40.0, page.end.y - 40.0))
	check("a click outside keeps it up and reaches what is under it", [carried.call("is_raised"), behind_clicks[0]], [true, 1])
	game.visitor_state = game.VisitorState.TALKING
	game.changed.emit()
	check("while a customer talks it is down", [carried.call("is_raised"), corner.visible], [false, true])
	game.visitor_state = game.VisitorState.NONE
	game.changed.emit()
	check("and up again after", carried.call("is_raised"), true)
	await create_timer(float(carried.get("raise_seconds")) + 0.1).timeout
	_click_at(paper.get_global_rect().position + paper.call("fold_rect").get_center())
	check("a click on the folded corner lowers it", [carried.call("is_raised"), corner.visible, behind_clicks[0]], [false, true, 1])
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
	check("no folded corner beside it", paper.get("folded"), false)
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


# The stream of the newest sound player under [param node]; null: none.
func _latest_sound(node: Node) -> AudioStream:
	var players := node.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer or n is AudioStreamPlayer3D)
	return players[-1].get(&"stream") if not players.is_empty() else null


# A left press and release at [param at], in the window's coordinates, through the whole input chain.
func _click_at(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = button
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


# While the page is raised, a left click on the trash can throws the page in at once and keeps the part
# in the hand.
func _check_trash_raised() -> void:
	var can: Node3D = load("res://props/trash_can.tscn").instantiate()  # untyped: TrashCan names Game
	can.add_to_group(&"trash_can")
	var thrown := _count_plays(can)
	root.add_child(can)
	var carried: Control = load("res://ui/carried_printout.tscn").instantiate()  # untyped: CarriedPrintout names Game
	root.add_child(carried)
	game.carry_printout(PAGE)
	game.take_new_part(load("res://parts/fan.tres"))
	await process_frame
	can.call("_set_hovered", true)
	carried.call("raise")
	_click_at(Vector2(4.0, 4.0))
	check("a left click on the can throws the raised page in, with a rustle", [game.printout, carried.call("is_raised"), thrown[0]], [PackedStringArray(), false, 1])
	check("the part stays in the hand", game.hand != null and game.hand.part == load("res://parts/fan.tres"), true)
	check("and the next page can be carried", game.carry_printout(FIX_PAGE), true)
	game.trash_printout()
	game.trash_part()
	carried.queue_free()
	can.queue_free()
	await process_frame


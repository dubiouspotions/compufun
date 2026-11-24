extends "res://tests/test.gd"
## Excel 97 (win95/office/excel.tscn) and its .xls cell format (XlsSheet, docs/xls.md): reading and
## writing the format, number formats, typing into cells, formatting them, a column's width, and
## saving into the running copy and opening the file again.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: its scripts name the Game autoload
const EXCEL := "res://win95/office/excel.tscn"
const BUDGET := """# prices
B width: 12
A1 bold: Item
B1 bold center: Price
A2: Apples
B2 currency: 1.5
"""


func run() -> void:
	_check_format()
	_check_numbers()
	await _check_excel()


func _check_format() -> void:
	var sheet := XlsSheet.parse(BUDGET)
	check("a clean file", sheet.errors, PackedStringArray())
	check("its cells", [sheet.cells.size(), sheet.width_of(1), sheet.width_of(0)], [4, 12.0, XlsSheet.STANDARD_WIDTH])
	var price := sheet.cell_at(Vector2i(1, 0))
	check("B1 bold and centred", [price.value, price.bold, price.italic, price.align], ["Price", true, false, XlsSheet.Align.CENTER])
	var apples := sheet.cell_at(Vector2i(1, 1))
	check("B2 in Currency with 2 decimals", [apples.format, apples.decimals, XlsSheet.shown(apples)], [XlsSheet.Format.CURRENCY, 2, "$1.50"])
	check("written back without the comment", sheet.to_text(), BUDGET.trim_prefix("# prices\n"))
	check("and read again the same", XlsSheet.parse(sheet.to_text()).to_text(), sheet.to_text())

	var odd := XlsSheet.parse("A1 italic underline right percent 1:  0.125\nC3 number 0: -2.5\nB2 boldly: x\nZZ9: y\nhello\nD width: wide")
	check("each bad line, by number", odd.errors, PackedStringArray([
		"Line 3: unknown word \"boldly\" (B2 boldly: x)",
		"Line 4: \"ZZ9\" is no cell between A1 and IV65536 (ZZ9: y)",
		"Line 5: no colon between the cell and its value (hello)",
		"Line 6: the width \"wide\" is no number (D width: wide)"]))
	var rate := odd.cell_at(Vector2i(0, 0))
	check("the good lines load: a space kept after the first", [rate.value, rate.italic, rate.underline, rate.align, rate.decimals], [" 0.125", true, true, XlsSheet.Align.RIGHT, 1])
	check("a value with a space before it is text", XlsSheet.shown(rate), " 0.125")
	check("Number 0 rounds", XlsSheet.shown(odd.cell_at(Vector2i(2, 2))), "-3")
	check("XlsSheet's names", [XlsSheet.column_name(0), XlsSheet.column_name(26), XlsSheet.column_name(255), XlsSheet.place_of("iv65536"), XlsSheet.place_of("IW1")],
			["A", "AA", "IV", Vector2i(255, 65535), Vector2i(-1, -1)])


func _check_numbers() -> void:
	var shown := func(value: String, format: XlsSheet.Format, decimals: int) -> String:
		var cell := XlsSheet.Cell.new()
		cell.value = value
		cell.format = format
		cell.decimals = decimals
		return XlsSheet.shown(cell)
	check("General", [shown.call("1.50", XlsSheet.Format.GENERAL, 0), shown.call("3", XlsSheet.Format.GENERAL, 0), shown.call("0.1", XlsSheet.Format.GENERAL, 0)], ["1.5", "3", "0.1"])
	check("Currency", [shown.call("1234.5", XlsSheet.Format.CURRENCY, 2), shown.call("-5", XlsSheet.Format.CURRENCY, 2)], ["$1,234.50", "($5.00)"])
	check("Percent and Comma", [shown.call("0.125", XlsSheet.Format.PERCENT, 1), shown.call("1234567", XlsSheet.Format.COMMA, 2)], ["12.5%", "1,234,567.00 "])
	check("Accounting: the $ apart, negatives in brackets, zero a dash", [shown.call("-5", XlsSheet.Format.ACCOUNTING, 2), shown.call("0", XlsSheet.Format.ACCOUNTING, 2)], ["(5.00)", "-   "])
	var dollars := XlsSheet.Cell.new()
	dollars.value = "3"
	dollars.format = XlsSheet.Format.ACCOUNTING
	check("Accounting's symbol", [XlsSheet.symbol(dollars), XlsSheet.symbol(XlsSheet.Cell.new())], ["$", ""])
	check("text stays text", [shown.call("'007", XlsSheet.Format.CURRENCY, 2), shown.call("=SUM(A1:A3)", XlsSheet.Format.GENERAL, 0)], ["007", "=SUM(A1:A3)"])

	var typed := func(text: String) -> Array:
		var cell := XlsSheet.Cell.new()
		XlsSheet.enter(cell, text)
		return [cell.value, cell.format, cell.decimals]
	check("typing $1,234.5", typed.call("$1,234.5"), ["1234.5", XlsSheet.Format.CURRENCY, 2])
	check("typing 12%", typed.call("12%"), ["0.12", XlsSheet.Format.PERCENT, 0])
	check("typing 1,234", typed.call("1,234"), ["1234", XlsSheet.Format.COMMA, 0])
	check("typing 1,23 is text", typed.call("1,23"), ["1,23", XlsSheet.Format.GENERAL, 0])


func _check_excel() -> void:
	var customer: Customer = load("res://customers/retired_accountant.tres")
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	await process_frame
	var desktop: Node = win95.get_node("Desktop")
	var setup: Win95Setup = win95.get_node("ComputerState").setup
	var program := Win95File.new()
	program.name = "EXCEL.EXE"
	program.program = load(EXCEL)
	setup.drive_c.append(program)
	var budget := Win95File.new()
	budget.name = "budget.xls"
	budget.contents = BUDGET
	setup.desktop.append(budget)

	win95.open_file(budget)
	var excel: Control = desktop.active_window()
	check("the .xls opens in Excel", [excel != null and excel.scene_file_path == EXCEL, excel.get_node("%TitleBar").title if excel != null else ""], [true, "Microsoft Excel - budget.xls"])
	if excel == null or excel.scene_file_path != EXCEL:
		win95.free()
		return
	await process_frame
	var sheet: Worksheet = excel.get_node("%Worksheet")
	var formula: LineEdit = excel.get_node("%FormulaText")
	check("A1 active, its value in the formula bar", [excel.get_node("%NameBox").text, formula.text, excel.tool(&"bold").button_pressed], ["A1", "Item", true])
	var file_menu: PopupMenu = excel.get_node("%File")
	var labels: Array[String] = []
	for i: int in file_menu.item_count:
		labels.append(file_menu.get_item_text(i))
	check("Excel 97's File menu", labels, ["New...", "Open...", "Close", "", "Save", "Save As...", "Save Workspace...", "",
			"Page Setup...", "Print Area", "Print Preview", "Print...", "", "Properties", "", "Exit"])

	_key(KEY_DOWN)
	_type("Pears")
	await process_frame  # LineEdit tells text_changed a frame later
	check("typing starts Enter mode", [sheet.mode, excel.get("_mode_cell").text, formula.text], [Worksheet.Mode.ENTER, "Enter", "Pears"])
	_key(KEY_TAB)
	check("Tab puts it in and moves right", [sheet.sheet.cell_at(Vector2i(0, 1)).value, XlsSheet.cell_name(sheet.active), sheet.mode], ["Pears", "B2", Worksheet.Mode.READY])
	check("the formula bar shows B2's value", formula.text, "1.5")
	_type("$2.25")
	_key(KEY_ENTER)
	var pears := sheet.sheet.cell_at(Vector2i(1, 1))
	check("$2.25 is a number in Currency", [pears.value, XlsSheet.shown(pears), XlsSheet.cell_name(sheet.active)], ["2.25", "$2.25", "B3"])
	_type("12%")
	_key(KEY_ESCAPE)
	check("Esc leaves the cell as it was", sheet.sheet.cell_at(Vector2i(1, 2)), null)
	_type("0.5")
	_key(KEY_ENTER)
	_key(KEY_UP)
	_key(KEY_UP, true)
	check("Shift+Up selects B2:B3, the status bar sums it", [sheet.selection(), excel.get("_sum_cell").text], [Rect2i(1, 1, 1, 2), "Sum=2.75"])
	excel.tool(&"percent").pressed.emit()
	pears = sheet.sheet.cell_at(Vector2i(1, 1))  # a change replaces the cell
	check("Percent Style on both", [XlsSheet.shown(pears), XlsSheet.shown(sheet.sheet.cell_at(Vector2i(1, 2)))], ["225%", "50%"])
	excel.tool(&"increase_decimal").pressed.emit()
	check("one more decimal", XlsSheet.shown(sheet.sheet.cell_at(Vector2i(1, 1))), "225.0%")
	_key(KEY_B, false, true)
	_key(KEY_I, false, true)
	excel.tool(&"align_right").pressed.emit()
	pears = sheet.sheet.cell_at(Vector2i(1, 1))
	check("Ctrl+B, Ctrl+I, Align Right", [pears.bold, pears.italic, pears.align, excel.tool(&"bold").button_pressed], [true, true, XlsSheet.Align.RIGHT, true])
	_key(KEY_F2)
	check("F2 edits the value, a percentage as one", [sheet.mode, formula.text], [Worksheet.Mode.EDIT, "225%"])
	_key(KEY_ESCAPE)

	var edge := Vector2(sheet.column_x(1) + sheet.column_pixels(1), 8)
	_mouse(sheet, edge, true)
	_mouse(sheet, edge + Vector2(35, 0), true, true)
	_mouse(sheet, edge + Vector2(35, 0), false)
	check("dragging B's edge widens it", sheet.sheet.width_of(1), snappedf(12.0 + 35.0 / 7.0, 0.01))

	_key(KEY_S, false, true)
	var saved := budget.contents
	check("Ctrl+S saves into the running copy", saved.contains("B2 bold italic right percent 1: 2.25\n") and saved.contains("A2: Pears\n") and saved.contains("B width: 17\n"), true)
	check("saved, nothing to ask", excel.call(&"_is_dirty"), false)
	_type("x")
	_key(KEY_ENTER)
	excel.request_close()
	var box: Control = desktop.active_window()
	check("closing with changes asks", box.get_node("%Text").text if box != excel else "", "Do you want to save the changes you made to 'budget.xls'?")
	if box != excel:
		box.call(&"_answer", "No")
	await process_frame
	check("No closes it", excel.visible, false)

	win95.open_file(budget)
	excel = desktop.active_window()
	await process_frame
	sheet = excel.get_node("%Worksheet")
	var again := sheet.sheet.cell_at(Vector2i(1, 1))
	check("opened again: as saved", [XlsSheet.shown(again), again.bold, sheet.sheet.width_of(1), sheet.sheet.cell_at(Vector2i(1, 3))], ["225.0%", true, 17.0, null])

	var broken := Win95File.new()
	broken.name = "broken.xls"
	broken.contents = "A1: fine\nB1 sparkly: no"
	setup.desktop.append(broken)
	win95.open_file(broken)
	var message: Control = desktop.active_window()
	check("a line Excel can't read: it says so, naming it", message.get_node("%Text").text if message != null else "",
			"Microsoft Excel can't read part of 'broken.xls'. The rest of it is open.\n\nLine 2: unknown word \"sparkly\" (B1 sparkly: no)")
	check("and shows the rest", sheet.sheet.cell_at(Vector2i(0, 0)).value, "fine")
	win95.free()


func _type(text: String) -> void:
	for letter: String in text:
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = letter.unicode_at(0)
		key.keycode = OS.find_keycode_from_string(letter.to_upper()) if letter.to_upper() != letter.to_lower() else KEY_NONE
		key.shift_pressed = letter != letter.to_lower()
		root.push_input(key)


func _key(keycode: Key, shift: bool = false, ctrl: bool = false) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	key.shift_pressed = shift
	key.ctrl_pressed = ctrl
	root.push_input(key)


# Headless runs have no mouse in the window, so the event goes straight to [param control].
func _mouse(control: Control, at: Vector2, pressed: bool, moving: bool = false) -> void:
	var event: InputEventMouse
	if moving:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = Vector2(35, 0)
		event = motion
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		event = button
	event.position = at
	control.call(&"_gui_input", event)

extends OfficeWindow
## Microsoft Excel 97 (EXCEL.EXE): one worksheet of numbers and text, with bold, italic, underline,
## alignment, number formats and column widths, and no formulas. It opens and saves .xls files in
## the plain text cell format of docs/xls.md (XlsSheet).

## The file extensions that Excel opens, lower case, without the dot.
@export var opens: Array[String] = ["xls"]

enum _ExcelFileMenu { SAVE_WORKSPACE = 50, PRINT_AREA }

@onready var _sheet: Worksheet = %Worksheet

var _mode_cell: Label
var _sum_cell: Label
var _window_menu: PopupMenu
var _loaded_text := ""  # the file's text as last loaded or saved, to tell unsaved changes


func _ready() -> void:
	super()
	_fit_file_menu()
	_window_menu = %MenuBar.get_node(^"Window")
	_window_menu.add_separator()
	_window_menu.add_check_item("1 " + untitled_name)
	_window_menu.set_item_checked(_window_menu.item_count - 1, true)
	_disable({"Edit": ["Paste", "Paste Special...", "Paste as Hyperlink", "Links...", "Object"],
			"Tools": ["Merge Workbooks..."], "Data": ["Refresh Data"], "Window": ["Unhide..."]})
	_mode_cell = add_status_cell("Ready")
	_mode_cell.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_status_cell("", 33)
	_sum_cell = add_status_cell("", 130)
	for width: float in [28, 29, 22]:
		add_status_cell("", width)
	%NameBox.add_item("A1")
	_sheet.formula_bar = %FormulaText
	_sheet.vertical_bar = %Rows
	_sheet.horizontal_bar = %Columns
	_sheet.state_changed.connect(_show_state)
	_sheet.edited.connect(edited)
	%SheetTabs.draw.connect(_draw_sheet_tabs)
	%EditMarks.draw.connect(_draw_edit_marks)
	_retitle()
	_show_state()
	_focus_default.call_deferred()


## The worksheet's text without formatting, row by row, cells apart by tabs.
func document_text() -> String:
	var rows: Dictionary[int, PackedStringArray] = {}
	var places := _sheet.sheet.cells.keys()
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for place: Vector2i in places:
		var shown := XlsSheet.symbol(_sheet.sheet.cells[place]) + XlsSheet.shown(_sheet.sheet.cells[place])
		if shown != "":
			if not rows.has(place.y):
				rows[place.y] = PackedStringArray()
			rows[place.y].append(shown)
	var lines: PackedStringArray = []
	for row: int in rows:
		lines.append("\t".join(rows[row]))
	return "\n".join(lines)


func _focus_default() -> void:
	if is_inside_tree():
		_sheet.grab_focus()


func _load(from: Win95File) -> void:
	var sheet := XlsSheet.parse(from.contents if from != null else "")
	_sheet.show_sheet(sheet)
	_loaded_text = sheet.to_text()
	if sheet.errors.is_empty():
		return
	var path := _state.path_of(from) if _state != null else from.name
	push_error("Excel: %s has lines that it can't read:\n%s" % [path, "\n".join(sheet.errors)])
	var desktop := get_parent() as Win95Desktop
	if desktop != null:
		var box: Node = desktop.open(preload("res://win95/message_box.tscn"), false)
		box.closed.connect(box.queue_free)
		box.show_message(_app_title, "Microsoft Excel can't read part of '%s'. The rest of it is open.\n\n%s" % [from.name, sheet.errors[0]])
		box.belong_to(self)


func _save(state: ComputerState, into: Win95File) -> void:
	_sheet.commit_edit()
	_loaded_text = _sheet.sheet.to_text()
	state.write_text(into, _loaded_text)


func _is_dirty() -> bool:
	return _sheet.mode != Worksheet.Mode.READY or _sheet.sheet.to_text() != _loaded_text


func _unsaved_question(_path: String) -> String:
	return "Do you want to save the changes you made to '%s'?" % file.name


func _retitle() -> void:
	super()
	if _window_menu != null:
		_window_menu.set_item_text(_window_menu.item_count - 1, "1 " + (file.name if file != null else untitled_name))


func _show_state() -> void:
	var cell := _sheet.active_cell()
	%NameBox.set_item_text(0, XlsSheet.cell_name(_sheet.active))
	%NameBox.select(0)
	_mode_cell.text = ["Ready", "Enter", "Edit"][_sheet.mode]
	%EditMarks.queue_redraw()
	var sum: Variant = _sheet.selection_sum()
	_sum_cell.text = "Sum=" + XlsSheet.general(sum) if sum != null else ""
	var on := {
		&"bold": cell != null and cell.bold, &"italic": cell != null and cell.italic, &"underline": cell != null and cell.underline,
		&"align_left": cell != null and cell.align == XlsSheet.Align.LEFT, &"center": cell != null and cell.align == XlsSheet.Align.CENTER,
		&"align_right": cell != null and cell.align == XlsSheet.Align.RIGHT,
	}
	for id: StringName in on:
		tool(id).set_pressed_no_signal(on[id])


func _menus() -> Array:
	return [
		["Edit", [["Undo", null, KEY_MASK_CTRL | KEY_Z], ["Repeat", null, KEY_MASK_CTRL | KEY_Y], [],
			["Cut", null, KEY_MASK_CTRL | KEY_X], ["Copy", null, KEY_MASK_CTRL | KEY_C], ["Paste", null, KEY_MASK_CTRL | KEY_V],
			["Paste Special...", null], ["Paste as Hyperlink", null], [], ["Fill", null], ["Clear", null], ["Delete...", null],
			["Delete Sheet", null], ["Move or Copy Sheet...", null], [], ["Find...", null, KEY_MASK_CTRL | KEY_F],
			["Replace...", null, KEY_MASK_CTRL | KEY_H], ["Go To...", null, KEY_MASK_CTRL | KEY_G], [], ["Links...", null], ["Object", null]]],
		["View", [["Normal", null], ["Page Break Preview", null], [], ["Toolbars", null], ["Formula Bar", null], ["Status Bar", null], [],
			["Header and Footer...", null], ["Comments", null], [], ["Custom Views...", null], ["Full Screen", null], ["Zoom...", null]]],
		["Insert", [["Cells...", null], ["Rows", null], ["Columns", null], ["Worksheet", null], ["Chart...", null], [],
			["Page Break", null], ["Function...", null], ["Name", null], ["Comment", null], [], ["Picture", null], ["Map...", null],
			["Object...", null], ["Hyperlink...", null, KEY_MASK_CTRL | KEY_K]]],
		["Format", [["Cells...", null, KEY_MASK_CTRL | KEY_1], ["Row", null], ["Column", null], ["Sheet", null], [],
			["AutoFormat...", null], ["Conditional Formatting...", null], ["Style...", null]]],
		["Tools", [["Spelling...", null, KEY_F7], ["AutoCorrect...", null], [], ["Share Workbook...", null], ["Track Changes", null],
			["Merge Workbooks...", null], ["Protection", null], [], ["Goal Seek...", null], ["Scenarios...", null], ["Auditing", null], [],
			["Macro", null], ["Add-Ins...", null], ["Customize...", null], ["Options...", null]]],
		["Data", [["Sort...", null], ["Filter", null], ["Form...", null], ["Subtotals...", null], ["Validation...", null], [],
			["Table...", null], ["Text to Columns...", null], ["Consolidate...", null], ["Group and Outline", null], [],
			["PivotTable Report...", null], [], ["Get External Data", null], ["Refresh Data", null]]],
		["Window", [["New Window", null], ["Arrange...", null], ["Hide", null], ["Unhide...", null], [], ["Split", null], ["Freeze Panes", null]]],
		["Help", [["Microsoft Excel Help", help_requested.emit, KEY_F1], [], ["Contents and Index", null],
			["What's This?", null, KEY_MASK_SHIFT | KEY_F1], ["Microsoft on the Web", null], ["Lotus 1-2-3 Help...", null], [],
			["About Microsoft Excel", null]]],
	]


func _standard_tools() -> Array:
	return [
		[&"new", "New", func() -> void: _on_file_menu(FileMenu.NEW)], [&"open", "Open", null], [&"save", "Save", save], "|",
		[&"print", "Print", null], [&"print_preview", "Print Preview", null], [&"spelling", "Spelling", null], "|",
		[&"cut", "Cut", null], [&"copy", "Copy", null], [&"paste", "Paste", null], [&"format_painter", "Format Painter", null], "|",
		[&"undo", "Undo", null], "v", [&"redo", "Redo", null], "v", "|",
		[&"hyperlink", "Insert Hyperlink", null], [&"web_toolbar", "Web Toolbar", null], "|",
		[&"autosum", "AutoSum", null], [&"paste_function", "Paste Function", null], [&"sort_ascending", "Sort Ascending", null],
		[&"sort_descending", "Sort Descending", null], "|",
		[&"chart_wizard", "Chart Wizard", null], [&"map", "Map", null], [&"drawing", "Drawing", null], "|",
		_combo(["100%"], 52), "|",
		[&"assistant", "Office Assistant", help_requested.emit],
	]


func _formatting_tools() -> Array:
	return [
		_combo(["Arial"], 132), _combo(["10"], 36), "|",
		[&"bold", "Bold", _sheet.toggle_style.bind(&"bold"), true], [&"italic", "Italic", _sheet.toggle_style.bind(&"italic"), true],
		[&"underline", "Underline", _sheet.toggle_style.bind(&"underline"), true], "|",
		[&"align_left", "Align Left", _sheet.set_align.bind(XlsSheet.Align.LEFT), true],
		[&"center", "Center", _sheet.set_align.bind(XlsSheet.Align.CENTER), true],
		[&"align_right", "Align Right", _sheet.set_align.bind(XlsSheet.Align.RIGHT), true],
		[&"merge_and_center", "Merge and Center", null], "|",
		[&"currency", "Currency Style", _sheet.set_format.bind(XlsSheet.Format.ACCOUNTING)],
		[&"percent", "Percent Style", _sheet.set_format.bind(XlsSheet.Format.PERCENT)],
		[&"comma", "Comma Style", _sheet.set_format.bind(XlsSheet.Format.COMMA)],
		[&"increase_decimal", "Increase Decimal", _sheet.change_decimals.bind(1)],
		[&"decrease_decimal", "Decrease Decimal", _sheet.change_decimals.bind(-1)], "|",
		[&"decrease_indent", "Decrease Indent", null], [&"increase_indent", "Increase Indent", null], "|",
		[&"borders", "Borders", null], "v", [&"fill_color", "Fill Color", null], "v", [&"font_color", "Font Color", null], "v",
	]


# A toolbar box listing [param items], [param width] pixels wide. Excel's boxes only show.
func _combo(items: Array, width: float) -> OptionButton:
	var box := OptionButton.new()
	for item: String in items:
		box.add_item(item)
	box.select(0)
	box.custom_minimum_size = Vector2(width, 20)
	box.focus_mode = Control.FOCUS_NONE
	box.fit_to_longest_item = false
	box.clip_text = true
	return box


# Office's File menu as Excel 97 has it: Save Workspace in place of Versions, Print Area after Page
# Setup, and no Send To.
func _fit_file_menu() -> void:
	var menu: PopupMenu = %File
	var versions := menu.get_item_index(OfficeFileMenu.VERSIONS)
	menu.remove_item(versions)
	_insert_stub(menu, "Save Workspace...", _ExcelFileMenu.SAVE_WORKSPACE, versions)
	_insert_stub(menu, "Print Area", _ExcelFileMenu.PRINT_AREA, menu.get_item_index(OfficeFileMenu.PAGE_SETUP) + 1)
	menu.remove_item(menu.get_item_index(OfficeFileMenu.SEND_TO))


static func _insert_stub(menu: PopupMenu, label: String, id: int, index: int) -> void:
	menu.add_item(label, id)
	menu.set_item_icon(menu.item_count - 1, Stub.dot())
	menu.set_item_index(menu.item_count - 1, index)


# Greys out the items that Excel 97 greys out with nothing to paste and no links.
func _disable(items: Dictionary) -> void:
	for title: String in items:
		var menu: PopupMenu = %MenuBar.get_node(NodePath(title))
		for i: int in menu.item_count:
			if menu.get_item_text(i) in items[title]:
				menu.set_item_disabled(i, true)


# The formula bar's Cancel X and Enter tick, while the player types into a cell. They only show.
func _draw_edit_marks() -> void:
	if _sheet.mode == Worksheet.Mode.READY:
		return
	var marks: Control = %EditMarks
	var mid := roundf(marks.size.y / 2.0)
	var cancel := Color8(168, 0, 87)  # as the 16-colour reference shows them
	var enter := Color8(0, 168, 87)
	marks.draw_line(Vector2(8, mid - 5), Vector2(18, mid + 5), cancel, 2.0)
	marks.draw_line(Vector2(18, mid - 5), Vector2(8, mid + 5), cancel, 2.0)
	marks.draw_line(Vector2(25, mid), Vector2(29, mid + 5), enter, 2.0)
	marks.draw_line(Vector2(29, mid + 5), Vector2(36, mid - 6), enter, 2.0)


# The sheet tabs: the four scroll arrows, then Sheet1 (white, in front), Sheet2 and Sheet3.
func _draw_sheet_tabs() -> void:
	var tabs: Control = %SheetTabs
	var palette: Win95Palette = preload("res://win95/theme/palette.tres")
	var ink := palette.button_text_color
	var mid := tabs.size.y / 2.0
	for i: int in 4:
		var x := 4.0 + i * 13.0
		var left := i < 2
		var tip := x + (2.0 if left else 6.0)
		var back := x + (6.0 if left else 2.0)
		tabs.draw_colored_polygon(PackedVector2Array([Vector2(tip, mid), Vector2(back, mid - 4), Vector2(back, mid + 4)]), ink)
		if i == 0:
			tabs.draw_rect(Rect2(x, mid - 4, 1, 9), ink)
		elif i == 3:
			tabs.draw_rect(Rect2(x + 8, mid - 4, 1, 9), ink)
	var font := Worksheet.cell_font(false, false)
	var bold := Worksheet.cell_font(true, false)
	var x := 58.0
	var bottom := tabs.size.y - 1
	for i: int in 3:
		var label := "Sheet%d" % (i + 1)
		var face := bold if i == 0 else font
		var width := face.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, Worksheet.FONT_SIZE).x + 16
		var outline := PackedVector2Array([Vector2(x, 0), Vector2(x + 6, bottom), Vector2(x + width - 6, bottom), Vector2(x + width, 0)])
		tabs.draw_colored_polygon(outline, palette.window_color if i == 0 else palette.face_color)
		tabs.draw_polyline(outline, ink)
		tabs.draw_string(face, Vector2(x + 8, bottom - 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Worksheet.FONT_SIZE, ink)
		x += width - 6


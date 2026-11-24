extends OfficeWindow
## Microsoft Word 97 (WINWORD.EXE): a rich text page with bold, italic, underline, font sizes,
## alignment and red squiggles under misspelt words. It opens and saves .doc files as RTF
## (win95/rtf.gd), as WordPad does.

## The file extensions that Word opens, lower case, without the dot.
@export var opens: Array[String] = ["doc", "rtf"]

## The font sizes that the Formatting toolbar's size box lists, in points.
const SIZES: Array[int] = [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]

var _saved := ""  # the document as Rtf.write wrote it at the last open or save
var _cells: Dictionary[String, Label] = {}
var _style_box := OptionButton.new()
var _font_box := OptionButton.new()
var _size_box := OptionButton.new()
var _zoom_box := OptionButton.new()


@onready var _text: RichEditor = %Text


func _ready() -> void:
	super()
	_text.changed.connect(edited)
	_text.caret_moved.connect(_sync_tools)
	_size_box.item_selected.connect(func(index: int) -> void: _text.set_font_size(SIZES[index]); _text.grab_focus())
	for cell: Array in [["Page 1", 54], ["Sec 1", 46], ["1/1", 44], ["At 1\"", 58], ["Ln 1", 40], ["Col 1", 48]]:
		_cells[cell[0].get_slice(" ", 0)] = add_status_cell(cell[0], cell[1])
	for flag: String in ["REC", "TRK", "EXT", "OVR", "WPH"]:
		add_status_cell(flag, 30).modulate = Color(1, 1, 1, 0.45)  # off, as Word greys them
	_sync_tools()


func document_text() -> String:
	return _text.document.plain_text()


func _focus_default() -> void:
	_text.grab_focus()


func _load(from: Win95File) -> void:
	_text.set_document(Rtf.read(from.contents) if from != null else RichDocument.new())
	_saved = Rtf.write(_text.document)


func _save(state: ComputerState, into: Win95File) -> void:
	_saved = Rtf.write(_text.document)
	state.write_text(into, _saved)


func _is_dirty() -> bool:
	return file != null and Rtf.write(_text.document) != _saved


func _unsaved_question(path: String) -> String:
	return "Do you want to save the changes you made to %s?" % path.get_file()


# The toolbar shows the format at the caret, and the status bar where the caret is.
func _sync_tools() -> void:
	for pair: Array in [[&"bold", RichDocument.BOLD], [&"italic", RichDocument.ITALIC], [&"underline", RichDocument.UNDERLINE]]:
		tool(pair[0]).set_pressed_no_signal(_text.selection_has(pair[1]))
	var align := _text.current_align()
	for pair: Array in [[&"align_left", RichDocument.Align.LEFT], [&"center", RichDocument.Align.CENTER],
			[&"align_right", RichDocument.Align.RIGHT], [&"justify", RichDocument.Align.JUSTIFY]]:
		tool(pair[0]).set_pressed_no_signal(align == pair[1])
	var points := RichDocument.half_points(_text.current_format()) / 2.0
	var size_index := SIZES.find(int(points))
	if size_index >= 0 and points == int(points):
		_size_box.select(size_index)
	var place := _text.caret_line_and_column()
	_cells["Ln"].text = "Ln %d" % place.x
	_cells["Col"].text = "Col %d" % place.y
	_cells["At"].text = "At %s\"" % String.num(1.0 + _text.caret_top() / 96.0, 1).trim_suffix(".0")
	for edit: StringName in [&"cut", &"copy"]:
		tool(edit).disabled = not _text.has_selection()


func _menus() -> Array:
	return [
		["Edit", [["Undo", _edit.bind(&"undo"), KEY_MASK_CTRL | KEY_Z], ["Repeat", _edit.bind(&"redo"), KEY_MASK_CTRL | KEY_Y], [],
			["Cut", _edit.bind(&"cut"), KEY_MASK_CTRL | KEY_X], ["Copy", _edit.bind(&"copy"), KEY_MASK_CTRL | KEY_C], ["Paste", _edit.bind(&"paste"), KEY_MASK_CTRL | KEY_V],
			["Paste Special...", null], ["Paste as Hyperlink", null], [], ["Clear", null, KEY_DELETE],
			["Select All", _edit.bind(&"select_all"), KEY_MASK_CTRL | KEY_A], [], ["Find...", null, KEY_MASK_CTRL | KEY_F],
			["Replace...", null, KEY_MASK_CTRL | KEY_H], ["Go To...", null, KEY_MASK_CTRL | KEY_G], [], ["Links...", null], ["Object", null]]],
		["View", [["Normal", null], ["Online Layout", null], ["Page Layout", null], ["Outline", null], ["Master Document", null], [],
			["Toolbars", null], ["Ruler", null], ["Document Map", null], [], ["Header and Footer", null], ["Footnotes", null],
			["Comments", null], [], ["Full Screen", null], ["Zoom...", null]]],
		["Insert", [["Break...", null], ["Page Numbers...", null], ["Date and Time...", null], ["AutoText", null], ["Field...", null],
			["Symbol...", null], ["Comment", null], [], ["Footnote...", null], ["Caption...", null], ["Cross-reference...", null],
			["Index and Tables...", null], [], ["Picture", null], ["Text Box", null], ["File...", null], ["Object...", null],
			["Bookmark...", null], ["Hyperlink...", null, KEY_MASK_CTRL | KEY_K]]],
		["Format", [["Font...", null], ["Paragraph...", null], ["Bullets and Numbering...", null], ["Borders and Shading...", null], [],
			["Columns...", null], ["Tabs...", null], ["Drop Cap...", null], ["Text Direction...", null], ["Change Case...", null], [],
			["AutoFormat...", null], ["Style Gallery...", null], ["Style...", null], ["Background", null], [], ["Object...", null]]],
		["Tools", [["Spelling...", null, KEY_F7], ["Language", null], ["Word Count...", null], ["AutoSummarize...", null],
			["AutoCorrect...", null], [], ["Track Changes", null], ["Merge Documents...", null], ["Protect Document...", null], [],
			["Mail Merge...", null], ["Envelopes and Labels...", null], ["Letter Wizard...", null], [], ["Macro", null],
			["Templates and Add-Ins...", null], ["Customize...", null], ["Options...", null]]],
		["Table", [["Draw Table", null], ["Insert Table...", null], ["Delete Cells...", null], ["Merge Cells", null],
			["Split Cells...", null], [], ["Select Row", null], ["Select Column", null], ["Select Table", null], [],
			["Table AutoFormat...", null], ["Distribute Rows Evenly", null], ["Distribute Columns Evenly", null],
			["Cell Height and Width...", null], ["Headings", null], [], ["Convert Text to Table...", null], ["Sort...", null],
			["Formula...", null], ["Split Table", null], ["Hide Gridlines", null]]],
		["Window", [["New Window", null], ["Arrange All", null], ["Split", null]]],
		["Help", [["Microsoft Word Help", help_requested.emit, KEY_F1], [], ["Contents and Index", null],
			["What's This?", null, KEY_MASK_SHIFT | KEY_F1], ["Microsoft on the Web", null], ["WordPerfect Help...", null], [],
			["About Microsoft Word", null]]],
	]


func _standard_tools() -> Array:
	return [
		[&"new", "New", func() -> void: _on_file_menu(FileMenu.NEW)], [&"open", "Open", null], [&"save", "Save", save], "|",
		[&"print", "Print", null], [&"print_preview", "Print Preview", null], [&"spelling", "Spelling", null], "|",
		[&"cut", "Cut", _edit.bind(&"cut")], [&"copy", "Copy", _edit.bind(&"copy")], [&"paste", "Paste", _edit.bind(&"paste")], [&"format_painter", "Format Painter", null], "|",
		[&"undo", "Undo", _edit.bind(&"undo")], "v", [&"redo", "Redo", _edit.bind(&"redo")], "v", "|",
		[&"hyperlink", "Insert Hyperlink", null], [&"web_toolbar", "Web Toolbar", null], "|",
		[&"tables_borders", "Tables and Borders", null], [&"insert_table", "Insert Table", null],
		[&"insert_worksheet", "Insert Microsoft Excel Worksheet", null], [&"columns", "Columns", null], [&"drawing", "Drawing", null], "|",
		[&"document_map", "Document Map", null], [&"show_hide", "Show/Hide ¶", null], _combo(_zoom_box, ["100%"], 52), "|",
		[&"assistant", "Office Assistant", help_requested.emit],
	]


func _formatting_tools() -> Array:
	var sizes: Array[String] = []
	for size: int in SIZES:
		sizes.append(str(size))
	return [
		_combo(_style_box, ["Normal"], 90), _combo(_font_box, ["Times New Roman"], 110), _combo(_size_box, sizes, 36, SIZES.find(10)), "|",
		[&"bold", "Bold", _format.bind(RichDocument.BOLD), true], [&"italic", "Italic", _format.bind(RichDocument.ITALIC), true],
		[&"underline", "Underline", _format.bind(RichDocument.UNDERLINE), true], "|",
		[&"align_left", "Align Left", _align.bind(RichDocument.Align.LEFT), true], [&"center", "Center", _align.bind(RichDocument.Align.CENTER), true],
		[&"align_right", "Align Right", _align.bind(RichDocument.Align.RIGHT), true], [&"justify", "Justify", _align.bind(RichDocument.Align.JUSTIFY), true], "|",
		[&"numbering", "Numbering", null], [&"bullets", "Bullets", null], [&"decrease_indent", "Decrease Indent", null],
		[&"increase_indent", "Increase Indent", null], "|",
		[&"borders", "Borders", null], "v", [&"highlight", "Highlight", null], "v", [&"font_color", "Font Color", null], "v",
	]


# A toolbar box: [param box] listing [param items], [param width] pixels wide, showing [param shown].
func _combo(box: OptionButton, items: Array, width: float, shown: int = 0) -> OptionButton:
	for item: String in items:
		box.add_item(item)
	box.select(shown)
	box.custom_minimum_size = Vector2(width, 20)
	box.focus_mode = Control.FOCUS_NONE
	box.fit_to_longest_item = false
	box.clip_text = true
	return box


func _edit(action: StringName) -> void:
	_text.call(action)
	_text.grab_focus()


func _format(mask: int) -> void:
	_text.toggle(mask)
	_text.grab_focus()


func _align(align: RichDocument.Align) -> void:
	_text.set_align(align)
	_text.grab_focus()
